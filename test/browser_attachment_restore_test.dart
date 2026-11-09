import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/backup_archive.dart';
import 'package:quiet_campus/browser_archive_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:sodium/sodium_sumo.dart';

import 'browser_archive_controller_test.dart' show MemorySnapshots;

const fixturePassword = 'Fictional attachments QA 2026';

Uint8List fixtureWave() {
  const rate = 8000;
  final bytes = Uint8List(44 + rate * 2);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, rate * 2, Endian.little);
  for (var i = 0; i < rate; i++) {
    data.setInt16(
      44 + i * 2,
      (800 * math.sin(i * 2 * math.pi * 440 / rate)).round(),
      Endian.little,
    );
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SodiumSumo sodium;
  late Uint8List image;
  late Uint8List backup;
  late Attachment picture;
  late Attachment audio;
  final wave = fixtureWave();

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffd9eeea), ui.BlendMode.src);
    canvas.drawCircle(
      const ui.Offset(32, 32),
      18,
      ui.Paint()..color = const ui.Color(0xff237c75),
    );
    final drawing = recorder.endRecording();
    final bitmap = await drawing.toImage(64, 64);
    try {
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      image = png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      bitmap.dispose();
      drawing.dispose();
    }
    final source = BrowserArchiveController(MemorySnapshots(), sodium);
    try {
      await source.load();
      await source.createVault(fixturePassword);
      picture = await source.addAttachment('虚构图案.png', image);
      audio = await source.addAttachment('合成提示音.wav', wave);
      final date = DateTime(2026, 10, 26, 14, 30);
      await source.save(
        Entry(
          id: 'qa-with-attachments',
          title: '虚构附件恢复 QA',
          delta: const [
            {
              'insert': '中文 <A&B> 😀',
              'attributes': {'bold': true},
            },
            {'insert': '\n图片为几何图案，音频为合成提示音，不含任何人的照片或声音。\n'},
          ],
          tags: const ['附件验收'],
          attachments: [picture, audio],
          createdAt: date,
          updatedAt: date,
        ),
        baseRevision: 0,
      );
      backup = await source.backup();
    } finally {
      source.dispose();
    }
  });

  test(
    'real PNG and PCM WAV survive encrypted restore, reopen and title edit',
    () async {
      final store = MemorySnapshots();
      final target = BrowserArchiveController(store, sodium);
      try {
        await target.load();
        await target.restore(
          await BackupArchive.decode(backup).unlock(sodium, fixturePassword),
          expectedRevision: 0,
        );
        expect(await target.readAttachment(picture), image);
        expect(await target.readAttachment(audio), wave);
        final codec = await ui.instantiateImageCodec(
          await target.readAttachment(picture),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 64);
        frame.image.dispose();
        codec.dispose();
        target.lock();
        await target.load();
        await target.unlock(fixturePassword);
        final before = target.entry('qa-with-attachments')!;
        await target.save(
          Entry.fromJson(before.id, {...before.toJson(), 'title': '修改后仍有原件'}),
          baseRevision: target.revisionOf(before.id),
        );
        expect(target.entry(before.id)!.delta, before.delta);
        expect(await target.readAttachment(picture), image);
        expect(await target.readAttachment(audio), wave);
        final exported = utf8.decode(await target.backup());
        for (final plaintext in ['虚构', '修改后', '附件验收', '合成提示音']) {
          expect(exported, isNot(contains(plaintext)));
        }
      } finally {
        target.dispose();
      }
    },
  );

  test(
    'broken/missing/future attachment imports never change an existing archive',
    () async {
      final store = MemorySnapshots();
      final target = BrowserArchiveController(store, sodium);
      try {
        await target.load();
        await target.restore(
          await BackupArchive.decode(backup).unlock(sodium, fixturePassword),
          expectedRevision: 0,
        );
        final persisted = Uint8List.fromList(store.current!.bytes);
        final variants = <Uint8List>[];
        final future = jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
        future['v'] = 99;
        variants.add(Uint8List.fromList(utf8.encode(jsonEncode(future))));
        final missing = jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
        missing['attachments'] = <String, dynamic>{};
        variants.add(Uint8List.fromList(utf8.encode(jsonEncode(missing))));
        final tampered =
            jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
        final files = tampered['attachments'] as Map;
        final bytes = base64Decode(files[picture.id] as String)..[30] ^= 1;
        files[picture.id] = base64Encode(bytes);
        variants.add(Uint8List.fromList(utf8.encode(jsonEncode(tampered))));
        variants.add(
          Uint8List.fromList(backup.take(backup.length ~/ 2).toList()),
        );
        for (final invalid in variants) {
          await expectLater(() async {
            final opened = await BackupArchive.decode(invalid)
                .unlock(sodium, fixturePassword);
            opened.dispose();
          }, throwsA(anything));
          expect(store.current!.bytes, persisted);
          expect(await target.readAttachment(picture), image);
          expect(await target.readAttachment(audio), wave);
        }
      } finally {
        target.dispose();
      }
    },
  );

  test('writes explicitly fictional UI fixtures outside the served website', () async {
    final root = Directory('build/qa')..createSync(recursive: true);
    final output = await root.createTemp('browser-attachments-');
    await File('${output.path}/valid.json').writeAsBytes(backup, flush: true);
    final invalid = jsonDecode(utf8.decode(backup)) as Map<String, dynamic>;
    invalid['attachments'] = <String, dynamic>{};
    await File('${output.path}/missing-file.json')
        .writeAsString(jsonEncode(invalid), flush: true);
    invalid['v'] = 99;
    await File('${output.path}/future-version.json')
        .writeAsString(jsonEncode(invalid), flush: true);
    await File('${output.path}/README.txt').writeAsString(
      'FICTIONAL QA ONLY\nPassword: $fixturePassword\nOne geometric PNG + one synthetic 1-second PCM WAV. Not user data.\n',
    );
    final checked = await BackupArchive.decode(
      await File('${output.path}/valid.json').readAsBytes(),
    ).unlock(sodium, fixturePassword);
    try {
      expect(checked.entries.any((e) => e.id == 'qa-with-attachments'), true);
    } finally {
      checked.dispose();
    }
    // Only this test output has a public fixture password; never package it.
    debugPrint('FICTIONAL_BROWSER_QA=${output.absolute.path}');
  });
}
