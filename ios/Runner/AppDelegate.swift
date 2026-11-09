import Flutter
import UIKit
import UserNotifications
import EventKit
import EventKitUI
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var calendarChannel: FlutterMethodChannel?
  private var audioChannel: FlutterMethodChannel?
  private var audioPlayers: [String: AVAudioPlayer] = [:]
  private let eventStore = EKEventStore()
  private var calendarResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    NotificationCenter.default.addObserver(self, selector: #selector(pauseOriginalAudio),
      name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(interruptOriginalAudio(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QuietCampusCalendar") else { return }
    calendarChannel = FlutterMethodChannel(name: "cn.quietcampus/calendar", binaryMessenger: registrar.messenger())
    calendarChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "addEvent" else { result(FlutterMethodNotImplemented); return }
      self?.addCalendarEvent(call.arguments, result: result)
    }
    audioChannel = FlutterMethodChannel(name: "cn.quietcampus/original-audio", binaryMessenger: registrar.messenger())
    audioChannel?.setMethodCallHandler { [weak self] call, result in
      self?.originalAudio(call, result: result)
    }
  }

  @objc private func pauseOriginalAudio() {
    audioPlayers.values.forEach { $0.pause() }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  @objc private func interruptOriginalAudio(_ notification: Notification) {
    guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          type == AVAudioSession.InterruptionType.began.rawValue else { return }
    pauseOriginalAudio()
  }

  private func originalAudio(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
      result(FlutterError(code: "invalid_audio", message: "音频参数无效", details: nil)); return
    }
    do {
      if call.method == "dispose" {
        audioPlayers.removeValue(forKey: id)?.stop()
        if !audioPlayers.values.contains(where: { $0.isPlaying }) {
          try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        result(nil); return
      }
      if call.method == "load" {
        guard let bytes = args["bytes"] as? FlutterStandardTypedData,
              !bytes.data.isEmpty, bytes.data.count <= 20 * 1024 * 1024 else {
          result(FlutterError(code: "invalid_audio", message: "音频大小无效", details: nil)); return
        }
        audioPlayers.removeValue(forKey: id)?.stop()
        // AVAudioPlayer(data:) keeps this explicitly opened decrypted audio off disk.
        let player = try AVAudioPlayer(data: bytes.data)
        guard player.prepareToPlay() else {
          result(FlutterError(code: "invalid_audio", message: "无法准备音频", details: nil)); return
        }
        audioPlayers[id] = player
        result(nil); return
      }
      guard let player = audioPlayers[id] else {
        result(FlutterError(code: "audio_closed", message: "播放已关闭", details: nil)); return
      }
      switch call.method {
      case "resume":
        guard UIApplication.shared.applicationState == .active else {
          result(FlutterError(code: "audio_background", message: "请回到应用后播放", details: nil)); return
        }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        if player.currentTime >= player.duration { player.currentTime = 0 }
        guard player.play() else {
          result(FlutterError(code: "audio_failed", message: "无法播放音频", details: nil)); return
        }
        result(nil)
      case "pause": player.pause(); result(nil)
      case "seek":
        if let ms = args["ms"] as? NSNumber {
          player.currentTime = min(player.duration, max(0, ms.doubleValue / 1000))
        }
        result(nil)
      case "status":
        result(["duration": Int(player.duration * 1000),
                "position": Int(player.currentTime * 1000), "playing": player.isPlaying])
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "audio_failed", message: "暂时无法播放这段声音", details: nil))
    }
  }

  private func addCalendarEvent(_ arguments: Any?, result: @escaping FlutterResult) {
    guard calendarResult == nil,
          let args = arguments as? [String: Any], let title = args["title"] as? String,
          let start = args["start"] as? NSNumber, let end = args["end"] as? NSNumber,
          end.doubleValue > start.doubleValue else {
      result(FlutterError(code: "invalid_event", message: "日程无效或已有日历窗口打开", details: nil)); return
    }
    let presentEditor = { [weak self] in
      guard let self = self else { return }
      DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
          result(FlutterError(code: "calendar_unavailable", message: "无法打开日历编辑器", details: nil)); return
        }
        while let next = presenter.presentedViewController { presenter = next }
        let event = EKEvent(eventStore: self.eventStore)
        event.title = title
        event.startDate = Date(timeIntervalSince1970: start.doubleValue / 1000)
        event.endDate = Date(timeIntervalSince1970: end.doubleValue / 1000)
        if let reminder = args["reminder"] as? NSNumber {
          event.addAlarm(EKAlarm(absoluteDate: Date(timeIntervalSince1970: reminder.doubleValue / 1000)))
        }
        let editor = EKEventEditViewController()
        editor.eventStore = self.eventStore; editor.event = event; editor.editViewDelegate = self
        self.calendarResult = result
        presenter.present(editor, animated: true)
      }
    }
    if #available(iOS 17.0, *) {
      // EventKitUI owns permission and final saving; the app never reads calendars.
      presentEditor()
    } else {
      eventStore.requestAccess(to: .event) { allowed, _ in
        if allowed { presentEditor() } else {
          DispatchQueue.main.async { result(FlutterError(code: "calendar_denied", message: "日历权限未开启", details: nil)) }
        }
      }
    }
  }
}

extension AppDelegate: EKEventEditViewDelegate {
  func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    controller.dismiss(animated: true)
    calendarResult?(action == .saved)
    calendarResult = nil
  }
}
