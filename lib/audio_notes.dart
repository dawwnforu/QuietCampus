import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'archive_actions.dart';
import 'model.dart';
import 'app_language.dart';

const voiceSampleRate = 44100;
const maxVoiceSeconds = 120;
const maxVoicePcmBytes = voiceSampleRate * 2 * maxVoiceSeconds;

bool isAudioFile(String name) => RegExp(
  r'\.(wav|m4a|mp3|aac|ogg|flac)$',
  caseSensitive: false,
).hasMatch(name);

String audioTime(Duration time) =>
    '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

Uint8List voiceWav(Uint8List pcm) {
  if (pcm.isEmpty || pcm.length.isOdd || pcm.length > maxVoicePcmBytes) {
    throw const FormatException('录音为空或超出单段 2 分钟限制');
  }
  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  void text(int at, String value) =>
      wav.setRange(at, at + value.length, value.codeUnits);
  text(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  text(8, 'WAVEfmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, voiceSampleRate, Endian.little);
  header.setUint32(28, voiceSampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);
  return wav;
}

Future<Attachment?> recordOriginalAudio(
  BuildContext context,
  ArchiveActions archive,
) => showDialog<Attachment>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _VoiceRecorder(archive: archive),
);

Future<void> playOriginalAudio(
  BuildContext context,
  ArchiveActions archive,
  Attachment file,
) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Text(file.name),
    content: AudioPlayback(
      archive: archive,
      load: () => archive.readAttachment(file),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t('关闭')),
      ),
    ],
  ),
);

class _VoiceRecorder extends StatefulWidget {
  const _VoiceRecorder({required this.archive});
  final ArchiveActions archive;
  @override
  State<_VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<_VoiceRecorder>
    with WidgetsBindingObserver {
  AudioRecorder? recorder;
  StreamSubscription<Uint8List>? subscription;
  StreamSubscription<RecordState>? stateSubscription;
  Timer? timer;
  final clock = Stopwatch();
  Uint8List? pcm;
  Uint8List? wav;
  int length = 0;
  bool recording = false;
  bool processing = false;
  bool leaving = false;
  bool foreground = true;
  String? error;
  String? notice;
  bool formatSupported = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.archive.addListener(checkLock);
  }

  void checkLock() {
    if (!widget.archive.unlocked) {
      unawaited(releaseRecorder());
      clear();
      if (mounted) {
        setState(() {
          recording = false;
          processing = false;
          error = '档案已锁定，录音已关闭';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission sheets can be inactive; only leaving the foreground ends capture.
    foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!foreground && recording) unawaited(finish(interrupted: true));
  }

  void clear() {
    pcm?.fillRange(0, pcm!.length, 0);
    pcm = null;
    wav?.fillRange(0, wav!.length, 0);
    wav = null;
    length = 0;
  }

  Future<void> releaseRecorder() async {
    timer?.cancel();
    timer = null;
    clock.stop();
    final active = recorder;
    recorder = null;
    await subscription?.cancel();
    subscription = null;
    await stateSubscription?.cancel();
    stateSubscription = null;
    try {
      await active?.dispose();
    } catch (_) {
      /* Still clear application buffers. */
    }
  }

  Future<void> start() async {
    setState(() {
      processing = true;
      error = null;
    });
    try {
      final active = recorder = AudioRecorder();
      if (!await active.hasPermission()) {
        throw const FormatException('未开启麦克风权限，仍可继续写随笔或添加已有音频');
      }
      if (!mounted ||
          !widget.archive.unlocked ||
          !foreground ||
          recorder != active) {
        return;
      }
      formatSupported = true;
      await active.setOnConfigChanged((config) {
        formatSupported =
            config.sampleRate == voiceSampleRate &&
            config.numChannels == 1 &&
            config.encoder == AudioEncoder.pcm16bits;
        if (!formatSupported && recording) unawaited(finish(interrupted: true));
      });
      // PCM stays in bounded memory until encrypted by the existing attachment store.
      pcm = Uint8List(maxVoicePcmBytes);
      final stream = await active.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: voiceSampleRate,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      if (!mounted ||
          !widget.archive.unlocked ||
          !foreground ||
          recorder != active) {
        return;
      }
      if (!formatSupported) throw const FormatException('设备暂不支持此录音格式，可以添加已有音频');
      recording = true;
      clock.reset();
      clock.start();
      subscription = stream.listen(
        (chunk) {
          final buffer = pcm;
          if (buffer != null) {
            final count = chunk.length.clamp(0, buffer.length - length);
            buffer.setRange(length, length + count, chunk);
            length += count;
            if (length == buffer.length) unawaited(finish());
          }
          chunk.fillRange(0, chunk.length, 0);
        },
        onDone: () {
          if (recording) unawaited(finish(interrupted: true));
        },
        onError: (Object _) {
          unawaited(finish(interrupted: true));
        },
      );
      stateSubscription = active.onStateChanged().listen(
        (state) {
          if (recording && state != RecordState.record) {
            unawaited(finish(interrupted: true));
          }
        },
        onError: (Object _) {
          if (recording) unawaited(finish(interrupted: true));
        },
      );
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (clock.elapsed.inSeconds >= maxVoiceSeconds) unawaited(finish());
        if (mounted) setState(() {});
      });
    } on FormatException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = '暂时无法录音，请检查麦克风是否可用');
    } finally {
      if (!recording) await releaseRecorder();
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> finish({bool interrupted = false}) async {
    if (!recording) return;
    setState(() {
      recording = false;
      processing = true;
    });
    try {
      await recorder?.stop();
    } catch (_) {
      interrupted = true;
    } finally {
      await releaseRecorder();
    }
    if (!mounted || !widget.archive.unlocked) {
      clear();
      if (mounted) setState(() => processing = false);
      return;
    }
    try {
      if (!formatSupported) throw const FormatException('录音格式不兼容');
      wav = voiceWav(Uint8List.sublistView(pcm!, 0, length - length % 2));
      notice = interrupted ? '录音已中断，已录到的声音保留在这里，请试听后决定是否留下。' : null;
    } catch (_) {
      error = formatSupported ? '没有录到声音，可以重新录制' : '设备录音格式不兼容，可以添加已有音频';
    } finally {
      pcm?.fillRange(0, pcm!.length, 0);
      pcm = null;
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> keep() async {
    if (wav == null || !widget.archive.unlocked) return;
    setState(() => processing = true);
    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final file = await widget.archive.addAttachment('原声-$stamp.wav', wav!);
      if (!mounted || !widget.archive.unlocked) return;
      setState(() => leaving = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) setState(() => error = '未能保存声音，录音仍在这里，请重试');
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> discard() async {
    setState(() => processing = true);
    await releaseRecorder();
    clear();
    if (!mounted) return;
    setState(() => leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    widget.archive.removeListener(checkLock);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(releaseRecorder());
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!recording && !processing && wav == null),
    child: AlertDialog(
      title: Text(context.t('留一段原声')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('留下当时的语气与声音。只录音，不转文字；保存后随档案加密。每段最多 2 分钟。')),
              const SizedBox(height: 16),
              if (recording)
                Text(
                  '${context.t('正在录音')} · ${audioTime(Duration(milliseconds: length * 1000 ~/ (voiceSampleRate * 2)))}',
                  semanticsLabel: context.t('正在录音'),
                ),
              if (processing) const LinearProgressIndicator(),
              if (notice != null) Text(context.t(notice!)),
              if (wav != null && !processing)
                AudioPlayback(
                  archive: widget.archive,
                  load: () async => Uint8List.fromList(wav!),
                ),
              if (error != null)
                Semantics(liveRegion: true, child: Text(context.t(error!))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: processing ? null : discard,
          child: Text(
            wav != null || recording ? context.t('放弃录音') : context.t('取消'),
          ),
        ),
        if (recording)
          FilledButton(
            onPressed: processing ? null : finish,
            child: Text(context.t('结束录音')),
          )
        else if (wav != null)
          FilledButton(
            onPressed: processing ? null : keep,
            child: Text(context.t('加入这篇随笔')),
          )
        else
          FilledButton(
            onPressed: processing || !widget.archive.unlocked ? null : start,
            child: Text(context.t('开始录音')),
          ),
      ],
    ),
  );
}

// audioplayers writes BytesSource to disk on iOS; use AVAudioPlayer(data:) there.
class MemoryAudioPlayer {
  static const channel = MethodChannel('cn.quietcampus/original-audio');
  final id = const Uuid().v4();
  AudioPlayer? player;
  Future<void>? loading;
  bool disposed = false;
  bool get ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<T?> native<T>(
    String method, [
    Map<String, Object> arguments = const {},
  ]) => channel.invokeMethod<T>(method, {'id': id, ...arguments});

  Future<void> load(Uint8List bytes) => loading = prepare(bytes);
  Future<void> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('音频大小无效');
    }
    if (ios) {
      await native<void>('load', {'bytes': bytes});
    } else if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows) {
      player = AudioPlayer();
      await player!.setReleaseMode(ReleaseMode.stop);
      final wav =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';
      await player!.setSource(
        BytesSource(bytes, mimeType: wav ? 'audio/wav' : null),
      );
    } else {
      throw UnsupportedError('此平台暂未接入内存音频播放');
    }
  }

  Future<void> resume() async {
    if (disposed) return;
    if (ios) {
      await native<void>('resume');
    } else {
      await player!.resume();
    }
  }

  Future<void> pause() async {
    if (disposed) return;
    if (ios) {
      await native<void>('pause');
    } else {
      await player!.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (disposed) return;
    if (ios) {
      await native<void>('seek', {'ms': position.inMilliseconds});
    } else {
      await player!.seek(position);
    }
  }

  Future<({Duration duration, Duration position, bool playing})>
  status() async {
    if (ios) {
      final data = (await native<Map>('status'))!;
      return (
        duration: Duration(milliseconds: data['duration'] as int),
        position: Duration(milliseconds: data['position'] as int),
        playing: data['playing'] as bool,
      );
    }
    return (
      duration: await player!.getDuration() ?? Duration.zero,
      position: await player!.getCurrentPosition() ?? Duration.zero,
      playing: player!.state == PlayerState.playing,
    );
  }

  Future<void> dispose() async {
    disposed = true;
    try {
      await loading;
    } catch (_) {
      /* Dispose partially prepared players too. */
    }
    if (ios) {
      await native<void>('dispose');
    } else {
      await player?.dispose();
    }
  }
}

class AudioPlayback extends StatefulWidget {
  const AudioPlayback({super.key, required this.archive, required this.load});
  final ArchiveActions archive;
  final Future<Uint8List> Function() load;
  @override
  State<AudioPlayback> createState() => _AudioPlaybackState();
}

class _AudioPlaybackState extends State<AudioPlayback>
    with WidgetsBindingObserver {
  MemoryAudioPlayer? player;
  Uint8List? bytes;
  Timer? timer;
  Future<void>? closing;
  bool busy = false;
  bool playing = false;
  bool foreground = true;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.archive.addListener(checkLock);
  }

  void checkLock() {
    if (!widget.archive.unlocked) unawaited(clear());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) unawaited(clear());
  }

  Future<void> clear({bool notify = true}) async {
    timer?.cancel();
    timer = null;
    final active = player;
    player = null;
    final data = bytes;
    bytes = null;
    playing = false;
    if (notify && mounted) setState(() {});
    final previous = closing;
    closing = () async {
      await previous;
      try {
        await active?.dispose();
      } catch (_) {
        /* Never retain application plaintext on a player failure. */
      }
      data?.fillRange(0, data.length, 0);
    }();
    await closing;
  }

  Future<void> refresh() async {
    final active = player;
    if (active == null || busy) return;
    try {
      final state = await active.status();
      if (!mounted || player != active) return;
      setState(() {
        duration = state.duration;
        position = state.position;
        playing = state.playing;
      });
    } catch (_) {
      await clear();
      if (mounted) setState(() => error = '播放已停止，可以重试');
    }
  }

  Future<void> toggle() async {
    if (busy || !foreground || !widget.archive.unlocked) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await closing;
      if (!mounted || !foreground || !widget.archive.unlocked) return;
      if (player == null) {
        final data = await widget.load();
        if (!mounted || !foreground || !widget.archive.unlocked) {
          data.fillRange(0, data.length, 0);
          return;
        }
        bytes = data;
        final active = player = MemoryAudioPlayer();
        await active.load(data);
        if (!mounted ||
            player != active ||
            !foreground ||
            !widget.archive.unlocked) {
          return;
        }
        await active.resume();
        if (!mounted ||
            player != active ||
            !foreground ||
            !widget.archive.unlocked) {
          return;
        }
        playing = true;
        timer = Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => unawaited(refresh()),
        );
      } else if (playing) {
        await player!.pause();
        playing = false;
      } else {
        if (duration > Duration.zero && position >= duration) {
          await player!.seek(Duration.zero);
        }
        await player!.resume();
        playing = true;
      }
    } catch (_) {
      await clear();
      if (mounted) error = '暂时无法播放，请检查音频是否完整；原附件仍保留。';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> seek(double ms) async {
    try {
      await player?.seek(Duration(milliseconds: ms.round()));
      await refresh();
    } catch (_) {
      await clear();
      if (mounted) setState(() => error = '暂时无法跳转播放位置');
    }
  }

  @override
  void dispose() {
    widget.archive.removeListener(checkLock);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(clear(notify: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.t(playing ? '暂停原声' : '播放原声'),
              onPressed: busy || !widget.archive.unlocked ? null : toggle,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
            ),
            Flexible(
              child: Text('${audioTime(position)} / ${audioTime(duration)}'),
            ),
          ],
        ),
        Slider(
          value: position.inMilliseconds
              .clamp(0, duration.inMilliseconds)
              .toDouble(),
          max: duration.inMilliseconds > 0
              ? duration.inMilliseconds.toDouble()
              : 1,
          label: audioTime(position),
          semanticFormatterCallback: (value) =>
              audioTime(Duration(milliseconds: value.round())),
          onChanged: duration > Duration.zero && !busy && player != null
              ? seek
              : null,
        ),
        if (error != null)
          Semantics(liveRegion: true, child: Text(context.t(error!))),
        if (!widget.archive.unlocked) Text(context.t('档案已锁定，播放已关闭')),
      ],
    ),
  );
}
