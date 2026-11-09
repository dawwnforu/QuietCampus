import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:quiet_campus/audio_notes.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/editor.dart';
import 'package:quiet_campus/model.dart';

class FakeRecorder extends RecordPlatform {
  bool allowed = true;
  int starts = 0;
  int releases = 0;
  RecordConfig? config;
  Completer<bool>? permission;
  late final chunks = StreamController<Uint8List>.broadcast();
  @override
  Future<void> create(String id) async {}
  @override
  Future<bool> hasPermission(String id, {bool request = true}) async =>
      permission == null ? allowed : await permission!.future;
  @override
  Stream<RecordState> onStateChanged(String id) => const Stream.empty();
  @override
  void setOnConfigChanged(String id, void Function(RecordConfig)? handler) {}
  @override
  Future<Stream<Uint8List>> startStream(String id, RecordConfig config) async {
    starts++;
    this.config = config;
    return chunks.stream;
  }

  @override
  Future<String?> stop(String id) async {
    unawaited(chunks.close());
    return null;
  }

  @override
  Future<void> dispose(String id) async {
    releases++;
    unawaited(chunks.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AudioArchive extends DemoController {
  bool open = true;
  bool failWrite = false;
  int additions = 0;
  Uint8List? savedBytes;
  Uint8List? lastRead;
  Completer<Uint8List>? pendingRead;
  @override
  bool get unlocked => open;
  @override
  Future<Attachment> addAttachment(String name, Uint8List bytes) async {
    if (failWrite) throw StateError('test write failure');
    additions++;
    savedBytes = bytes;
    return super.addAttachment(name, bytes);
  }

  @override
  Future<Uint8List> readAttachment(Attachment file) async =>
      lastRead = await (pendingRead == null
          ? super.readAttachment(file)
          : pendingRead!.future);
  void lock() {
    open = false;
    notifyListeners();
  }
}

void testAudioWidget(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

Future<void> flushAudio(WidgetTester tester) async {
  // Plugin stream cancellation can complete on the originating real zone.
  for (var step = 0; step < 6; step++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRecorder recorder;
  late RecordPlatform previous;
  final playerCalls = <MethodCall>[];
  bool playing = false;
  int position = 0;

  setUp(() {
    previous = RecordPlatform.instance;
    RecordPlatform.instance = recorder = FakeRecorder();
    playerCalls.clear();
    playing = false;
    position = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MemoryAudioPlayer.channel, (call) async {
          playerCalls.add(call);
          switch (call.method) {
            case 'load':
              return null;
            case 'resume':
              playing = true;
            case 'pause':
              playing = false;
            case 'dispose':
              playing = false;
            case 'seek':
              position = (call.arguments as Map)['ms'] as int;
            case 'status':
              return {
                'duration': 1000,
                'position': position,
                'playing': playing,
              };
          }
          return null;
        });
  });
  tearDown(() {
    RecordPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MemoryAudioPlayer.channel, null);
  });

  Future<void> mount(
    WidgetTester tester,
    AudioArchive archive, {
    Entry? entry,
  }) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ArchiveDemo(controller: archive));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => EntryEditor(controller: archive, entry: entry),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('record-original-audio')));
    await tester.tap(find.byKey(const Key('record-original-audio')));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester) async {
    await tester.tap(find.text('开始录音'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    recorder.chunks.add(Uint8List.fromList([1, 2, 3, 4]));
    await tester.pump();
    await tester.tap(find.text('结束录音'));
    await flushAudio(tester);
    await tester.pumpAndSettle();
  }

  test('WAV is mono PCM with correct sizes and bounded memory', () {
    final result = voiceWav(Uint8List.fromList([1, 2, 3, 4]));
    final header = ByteData.sublistView(result);
    expect(ascii.decode(result.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(result.sublist(8, 16)), 'WAVEfmt ');
    expect(header.getUint32(4, Endian.little), 40);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 44100);
    expect(header.getUint32(40, Endian.little), 4);
    expect(result.sublist(44), [1, 2, 3, 4]);
    for (final length in [0, 1, maxVoicePcmBytes + 2]) {
      expect(() => voiceWav(Uint8List(length)), throwsFormatException);
    }
    expect(
      voiceWav(Uint8List(maxVoicePcmBytes)).length,
      lessThan(20 * 1024 * 1024),
    );
    expect(isAudioFile('原声.WAV'), isTrue);
    expect(isAudioFile('原声.wav.exe'), isFalse);
  });

  testAudioWidget(
    'record, listen, retry save, keep audio-only note and reopen',
    (tester) async {
      final archive = AudioArchive()..entries = [];
      await mount(tester, archive);
      expect(recorder.starts, 0);
      await capture(tester);
      expect(recorder.config!.encoder, AudioEncoder.pcm16bits);
      expect(recorder.config!.autoGain, isFalse);
      expect(recorder.releases, 1);
      await tester.tap(find.byTooltip('播放原声'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(playerCalls.any((call) => call.method == 'load'), isTrue);
      expect(find.byTooltip('暂停原声'), findsOneWidget);
      await tester.tap(find.byTooltip('暂停原声'));
      await tester.pump();
      expect(playerCalls.any((call) => call.method == 'pause'), isTrue);
      archive.failWrite = true;
      await tester.tap(find.text('加入这篇随笔'));
      await tester.pumpAndSettle();
      expect(find.text('未能保存声音，录音仍在这里，请重试'), findsOneWidget);
      archive.failWrite = false;
      await tester.tap(find.text('加入这篇随笔'));
      await tester.pumpAndSettle();
      expect(archive.additions, 1);
      expect(archive.savedBytes!.every((byte) => byte == 0), isTrue);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final entry = archive.entries.single;
      expect(entry.plainText.trim(), isEmpty);
      expect(entry.kind, 'note');
      final restored = Entry.fromJson(entry.id, entry.toJson());
      final data = await archive.readAttachment(restored.attachments.single);
      expect(data.sublist(44), [1, 2, 3, 4]);
      expect(
        Entry.fromJson(entry.id, entry.toJson()).attachments.single.name,
        endsWith('.wav'),
      );
      // A saved attachment opens in the in-app player, not an external preview/export.
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(
        playOriginalAudio(context, archive, restored.attachments.single),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('播放原声'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pump();
      expect(playerCalls.any((call) => call.method == 'seek'), isTrue);
      archive.lock();
      await flushAudio(tester);
      await tester.pumpAndSettle();
      expect(archive.lastRead!.every((byte) => byte == 0), isTrue);
      expect(playerCalls.last.method, 'dispose');
      expect(find.text('档案已锁定，播放已关闭'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testAudioWidget(
    'permission denial and discard leave rich text and tags unchanged',
    (tester) async {
      final archive = AudioArchive();
      final entry = archive.entries.firstWhere((e) => e.kind == 'note');
      final before = jsonEncode(entry.toJson());
      recorder.allowed = false;
      await mount(tester, archive, entry: entry);
      await tester.tap(find.text('开始录音'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未开启麦克风权限'), findsOneWidget);
      expect(recorder.starts, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(jsonEncode(archive.entry(entry.id)!.toJson()), before);
      expect(archive.additions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testAudioWidget('adding original audio preserves existing Delta and tags', (
    tester,
  ) async {
    final archive = AudioArchive();
    final entry = archive.entries.firstWhere((e) => e.kind == 'note');
    final originalDelta = jsonEncode(entry.delta);
    final originalTags = [...entry.tags];
    await mount(tester, archive, entry: entry);
    await capture(tester);
    await tester.tap(find.text('加入这篇随笔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = archive.entry(entry.id)!;
    expect(jsonEncode(saved.delta), originalDelta);
    expect(saved.tags, originalTags);
    expect(saved.attachments.length, entry.attachments.length + 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await flushAudio(tester);
  });

  testAudioWidget(
    'empty recording can be discarded without adding an attachment',
    (tester) async {
      final archive = AudioArchive();
      await mount(tester, archive);
      await tester.tap(find.text('开始录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('结束录音'));
      await flushAudio(tester);
      await tester.pumpAndSettle();
      expect(find.text('没有录到声音，可以重新录制'), findsOneWidget);
      expect(archive.additions, 0);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await flushAudio(tester);
    },
  );

  testAudioWidget(
    'background ends capture, retains draft; discard does not attach',
    (tester) async {
      final archive = AudioArchive();
      final entry = archive.entries.firstWhere((e) => e.kind == 'note');
      await mount(tester, archive, entry: entry);
      await tester.tap(find.text('开始录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final chunk = Uint8List.fromList([1, 2]);
      recorder.chunks.add(chunk);
      await tester.pump();
      expect(chunk, [0, 0]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await flushAudio(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('已录到的声音保留'), findsOneWidget);
      expect(recorder.releases, 1);
      await tester.tap(find.text('放弃录音'));
      await tester.pumpAndSettle();
      expect(archive.additions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testAudioWidget('locking during microphone permission never starts capture', (
    tester,
  ) async {
    final archive = AudioArchive();
    recorder.permission = Completer<bool>();
    await mount(tester, archive);
    await tester.tap(find.text('开始录音'));
    await tester.pump();
    archive.lock();
    recorder.permission!.complete(true);
    await tester.pumpAndSettle();
    expect(recorder.starts, 0);
    expect(archive.additions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testAudioWidget(
    'locking during recording releases microphone and allows closing',
    (tester) async {
      final archive = AudioArchive();
      await mount(tester, archive);
      await tester.tap(find.text('开始录音'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      recorder.chunks.add(Uint8List.fromList([1, 2]));
      await tester.pump();
      archive.lock();
      await flushAudio(tester);
      await tester.pumpAndSettle();
      expect(recorder.releases, 1);
      expect(find.text('档案已锁定，录音已关闭'), findsOneWidget);
      expect(archive.additions, 0);
      await tester.tap(find.text('取消'));
      await flushAudio(tester);
      await tester.pumpAndSettle();
      expect(find.text('开始录音'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await flushAudio(tester);
    },
  );

  testAudioWidget('late decrypted audio is wiped after locking, never played', (
    tester,
  ) async {
    final archive = AudioArchive()..pendingRead = Completer<Uint8List>();
    final data = voiceWav(Uint8List.fromList([1, 2]));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Scaffold(
          body: AudioPlayback(
            archive: archive,
            load: () => archive.pendingRead!.future,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Play recording'));
    await tester.pump();
    archive.lock();
    archive.pendingRead!.complete(data);
    await tester.pumpAndSettle();
    expect(data.every((byte) => byte == 0), isTrue);
    expect(playerCalls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
