import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:quiet_campus/backup_archive.dart';
import 'package:quiet_campus/browser_archive_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/snapshot_store.dart';

class MemorySnapshots implements SnapshotStore {
  StoredSnapshot? current;
  bool fail = false;
  @override
  Future<StoredSnapshot?> read() async => current;
  @override
  Future<int> commit(Uint8List bytes, {required int baseRevision}) async {
    if (fail) throw StateError('simulated full disk');
    if ((current?.revision ?? 0) != baseRevision) throw StateError('stale');
    current = StoredSnapshot(baseRevision + 1, Uint8List.fromList(bytes));
    return current!.revision;
  }
}

void main() {
  late SodiumSumo sodium;
  late MemorySnapshots storage;
  late BrowserArchiveController c;
  const password = 'Fictional browser test 口令';
  Entry note(
    String id,
    String title, {
    List<String> tags = const [],
    List<Attachment> files = const [],
  }) => Entry(
    id: id,
    title: title,
    tags: tags,
    attachments: files,
    delta: const [
      {
        'insert': '中文 <A&B> 😀\n',
        'attributes': {'bold': true},
      },
    ],
    createdAt: DateTime(2026, 10, 26),
    updatedAt: DateTime(2026, 10, 26),
  );
  setUpAll(() async => sodium = await SodiumSumoInit.init());
  setUp(() async {
    storage = MemorySnapshots();
    c = BrowserArchiveController(storage, sodium);
    await c.load();
    await c.createVault(password);
  });
  tearDown(() => c.dispose());

  test('save, reopen, unlock, isolated restore and duplicate restore preserve full rich text and files', () async {
    final file = await c.addAttachment(
      '虚构声音.wav',
      Uint8List.fromList([1, 2, 3]),
    );
    await c.save(
      note('fixture-1', '虚构随笔', tags: ['校园'], files: [file]),
      baseRevision: 0,
    );
    final backup = await c.backup();
    expect(utf8.decode(storage.current!.bytes), isNot(contains('虚构')));
    c.lock();
    await c.load();
    await c.unlock(password);
    expect(c.entry('fixture-1')!.delta.first['attributes'], {'bold': true});
    expect(await c.readAttachment(file), [1, 2, 3]);
    expect(c.knownTags, ['校园']);
    final isolated = BrowserArchiveController(MemorySnapshots(), sodium);
    try {
      await isolated.load();
      final archive = BackupArchive.decode(backup);
      expect(
        await isolated.restore(
          await archive.unlock(sodium, password),
          expectedRevision: 0,
        ),
        true,
      );
      expect(isolated.entry('fixture-1')!.title, '虚构随笔');
      final revision = isolated.storageRevision;
      expect(
        await isolated.restore(
          await archive.unlock(sodium, password),
          expectedRevision: revision,
        ),
        false,
      );
      expect(isolated.storageRevision, revision);
      expect(isolated.entries.where((e) => e.isRecord).length, 1);
      expect(await isolated.readAttachment(file), [1, 2, 3]);
    } finally {
      isolated.dispose();
    }
  });

  test(
    'failed save or restore leaves prior persisted and visible records usable',
    () async {
      await c.save(note('fixture-1', '原来的虚构记录'), baseRevision: 0);
      final previous = Uint8List.fromList(storage.current!.bytes);
      final candidate = await BackupArchive.decode(previous)
          .unlock(sodium, password);
      await c.save(note('fixture-2', '仍应保留'), baseRevision: 0);
      final beforeFailure = Uint8List.fromList(storage.current!.bytes);
      storage.fail = true;
      await expectLater(
        c.save(note('fixture-1', '不能提交'), baseRevision: 1),
        throwsStateError,
      );
      expect(c.entry('fixture-1')!.title, '原来的虚构记录');
      await expectLater(
        c.restore(candidate, expectedRevision: c.storageRevision),
        throwsStateError,
      );
      candidate.dispose();
      expect(storage.current!.bytes, beforeFailure);
      expect(c.entry('fixture-2')!.title, '仍应保留');
      storage.fail = false;
      c.lock();
      await c.load();
      await c.unlock(password);
      expect(c.entry('fixture-2'), isNotNull);
    },
  );

  test(
    'stale writer and stale restore preview cannot overwrite newer records',
    () async {
      await c.save(note('fixture-1', '最初版本'), baseRevision: 0);
      final oldBackup = await c.backup();
      final other = BrowserArchiveController(storage, sodium);
      try {
        await other.load();
        await other.unlock(password);
        final previewRevision = c.storageRevision;
        await other.save(note('fixture-1', '另一个页面的新版本'), baseRevision: 1);
        await expectLater(
          c.save(note('fixture-1', '旧页面输入'), baseRevision: 1),
          throwsStateError,
        );
        final candidate = await BackupArchive.decode(oldBackup)
            .unlock(sodium, password);
        await expectLater(
          c.restore(candidate, expectedRevision: previewRevision),
          throwsStateError,
        );
        candidate.dispose();
        expect(c.entry('fixture-1')!.title, '最初版本');
        await c.sync();
        expect(c.stale, true);
        c.lock();
        await c.load();
        await c.unlock(password);
        expect(c.entry('fixture-1')!.title, '另一个页面的新版本');
      } finally {
        other.dispose();
      }
    },
  );

  test('tag rename/delete preserve unrelated text and attachments; tombstones survive reopen', () async {
    final file = await c.addAttachment('虚构证明.png', Uint8List.fromList([7]));
    final original = note(
      'fixture-1',
      '不可污染的标题',
      tags: ['旧标签', '保留'],
      files: [file],
    );
    await c.save(original, baseRevision: 0);
    await c.renameTag('旧标签', '新标签');
    expect(c.entry(original.id)!.tags, ['新标签', '保留']);
    expect(c.entry(original.id)!.delta, original.delta);
    await c.deleteTag('新标签');
    expect(c.entry(original.id)!.tags, ['保留']);
    expect(c.entry(original.id)!.title, original.title);
    expect(await c.readAttachment(file), [7]);
    await c.deleteEntry(c.entry(original.id)!);
    c.lock();
    await c.load();
    await c.unlock(password);
    expect(c.isDeleted(original.id), true);
    expect(c.entry(original.id), isNull);
    expect(c.knownTags, contains('保留'));
  });
}
