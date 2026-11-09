import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/app.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/materials.dart';
import 'package:quiet_campus/material_preview.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/overview.dart';
import 'package:quiet_campus/record_export.dart';

final imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
);

final class MemoryPickedFile extends PlatformFile {
  @override
  String get name => '示例证明.png';
  @override
  Uri get uri => Uri.dataFromBytes(imageBytes);
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int lengthSync() => imageBytes.length;
  @override
  Future<int> length() async => imageBytes.length;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(imageBytes);
  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList(imageBytes));
}

class MaterialPicker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [MemoryPickedFile()];
  @override
  Future<bool> clearTemporaryFiles() async => true;
}

class LockableDemo extends DemoController {
  bool open = true;
  bool failRead = false;
  Uint8List? lastRead;
  @override
  bool get unlocked => open;
  @override
  Future<Uint8List> readAttachment(Attachment file) async {
    if (failRead) throw StateError('offline');
    return lastRead = await super.readAttachment(file);
  }

  void lock() {
    open = false;
    entries = [];
    notifyListeners();
  }
}

Future<Entry> material(DemoController c) async {
  final file = await c.addAttachment('示例证明.png', imageBytes);
  final e = Entry(
    id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    title: '志愿服务证明',
    kind: 'material',
    delta: const [
      {'insert': '社区服务的成果\n'},
    ],
    tags: const ['志愿'],
    materialCategory: '经历证明',
    materialDate: DateTime(2026, 10, 20),
    attachments: [file],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  await c.save(e, baseRevision: 0);
  return e;
}

void main() {
  test('one encrypted-attachment identity serves many rich records; unlink and delete are independent', () async {
    final c = DemoController();
    final before = ArchiveStats(c.entries);
    final e = await material(c);
    expect(ArchiveStats(c.entries).records, before.records);
    expect(ArchiveStats(c.entries).characters, before.characters);
    expect(e.matches('经证'), isTrue);
    expect(e.matches('志服'), isTrue);
    final decoded = Entry.fromJson(e.id, jsonDecode(jsonEncode(e.toJson())));
    expect(decoded.materialCategory, '经历证明');
    expect(decoded.materialDate, DateTime(2026, 10, 20));
    expect(e.toJson()['v'], 2);
    final records = c.entries
        .where((r) => ['experience', 'project'].contains(r.kind))
        .take(2)
        .toList();
    final original = jsonEncode(records.first.delta);
    for (final record in records) {
      await setMaterialLink(c, record.id, e.id, true);
    }
    await setMaterialLink(c, records.first.id, e.id, true);
    for (final record in records) {
      final linked = c.entry(record.id)!;
      expect(linked.materialIds, {e.id});
      expect(linked.attachments, isEmpty);
      expect(Document.fromJson(linked.delta).toDelta().toJson(), linked.delta);
      expect(recordText(linked), contains('[材料引用：${e.id}'));
      final beforeSearch = jsonEncode(linked.toJson());
      linked.search('社区');
      expect(jsonEncode(linked.toJson()), beforeSearch);
    }
    expect(c.entries.expand((r) => r.attachments).length, 1);
    expect(
      (jsonDecode(recordsJson(c.entries))['records'] as List).any(
        (r) => r['kind'] == 'material',
      ),
      isFalse,
    );
    await setMaterialLink(c, records.first.id, e.id, false);
    expect(
      jsonEncode(
        c
            .entry(records.first.id)!
            .delta
            .take(records.first.delta.length)
            .toList(),
      ),
      original,
    );
    expect(c.entry(e.id), isNotNull);
    await c.deleteEntry(c.entry(records.first.id)!);
    expect(await c.readAttachment(e.attachments.single), imageBytes);
    await c.deleteEntry(e);
    expect(c.isDeleted(e.id), isTrue);
    expect(c.entry(records.last.id)!.materialIds, {e.id});
    c.dispose();
  });

  testWidgets(
    'import, edit, multi-reference, missing tombstone and narrow navigation',
    (tester) async {
      final oldPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = MaterialPicker();
      addTearDown(() => FilePickerPlatform.instance = oldPicker);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DemoController();
      await tester.pumpWidget(ArchiveDemo(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('材料库'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入材料'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择图片或 PDF · 最多 20 MiB'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '材料名称'), '奖学金证明');
      await tester.tap(find.text('保存材料'));
      await tester.pumpAndSettle();
      final saved = c.entries.firstWhere((e) => e.kind == 'material');
      expect(saved.attachments, hasLength(1));
      expect(await c.readAttachment(saved.attachments.single), imageBytes);
      await tester.tap(find.text('奖学金证明'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关联经历或项目'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('社区图书馆志愿服务'));
      await tester.pumpAndSettle();
      expect(
        c.entries.firstWhere((e) => e.kind == 'experience').materialIds,
        contains(saved.id),
      );
      await tester.tap(find.byTooltip('解除关联（保留记录和原件）'));
      await tester.pumpAndSettle();
      expect(c.entries.where((e) => e.materialIds.contains(saved.id)), isEmpty);
      expect(c.entry(saved.id), isNotNull);
      final note = c.entries.firstWhere((e) => e.isRecord);
      await setMaterialLink(c, note.id, saved.id, true);
      await c.deleteEntry(saved);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryDetail(
              entry: c.entry(note.id)!,
              controller: c,
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('材料已删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'the original editor inserts a material embed and saves rich text without copying the attachment',
    (tester) async {
      final c = DemoController();
      final e = await material(c);
      await tester.pumpWidget(ArchiveDemo(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('写日记'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '正文里的证明');
      await tester.scrollUntilVisible(
        find.text('插入材料引用'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('插入材料引用'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('志愿服务证明'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = c.entries.firstWhere((r) => r.title == '正文里的证明');
      expect(saved.materialIds, {e.id});
      expect(saved.attachments, isEmpty);
      expect(Document.fromJson(saved.delta).toDelta().toJson(), saved.delta);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'an unavailable original can be retried without replacing the reference',
    (tester) async {
      final c = LockableDemo();
      final e = await material(c);
      c.failRead = true;
      final before = jsonEncode(e.toJson());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: MaterialPreview(controller: c, file: e.attachments.single),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('原件暂未下载'), findsOneWidget);
      c.failRead = false;
      await tester.tap(find.text('重试下载'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(jsonEncode(c.entry(e.id)!.toJson()), before);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'image preview clears decrypted buffer and image cache on lock without touching original',
    (tester) async {
      final c = LockableDemo();
      final e = await material(c);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: MaterialPreview(controller: c, file: e.attachments.single),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final decrypted = c.lastRead!;
      c.lock();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(decrypted.every((byte) => byte == 0), isTrue);
      expect(await c.readAttachment(e.attachments.single), imageBytes);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
