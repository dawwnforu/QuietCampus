import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/local_store.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/sync_engine.dart';

class MaterialRemote implements SyncRemote {
  bool offline = true;
  final rows = <String, SealedRecord>{};
  final files = <String, Uint8List>{};
  final operations = <String>[];
  @override
  Future<void> upload(String id, Uint8List ciphertext) async {
    if (offline) throw StateError('offline');
    operations.add('file');
    files[id] = ciphertext;
  }

  @override
  Future<List<SealedRecord>> readAll() async {
    if (offline) throw StateError('offline');
    return rows.values.toList();
  }

  @override
  Future<Map<String, dynamic>> write(SealedRecord record) async {
    if (offline) throw StateError('offline');
    final current = rows[record.id];
    if (record.revision != (current?.revision ?? 0)) {
      return {'conflict': true, 'record': current!.toJson()};
    }
    operations.add('record');
    final saved = SealedRecord(
      id: record.id,
      revision: record.revision + 1,
      ciphertext: record.ciphertext,
      deleted: record.deleted,
    );
    rows[record.id] = saved;
    return {'conflict': false, 'record': saved.toJson()};
  }
}

void main() {
  test('Dart-encrypted material survives SQLite reopen, offline retry and remote deletion conflict', () async {
    // Only synthetic keys and ciphertext produced by tool/crypto_self_check.dart.
    final fixture = jsonDecode(
      await File('test/fixtures/material-vault.json').readAsString(),
    ) as Map;
    final backup = fixture['backup'] as Map;
    final sourceRows = (backup['records'] as List).cast<Map>();
    final directory = await Directory.systemTemp.createTemp(
      'quiet-material-test-',
    );
    final path = '${directory.path}/archive.sqlite';
    var store = LocalStore(path);
    final otherDevice = LocalStore(':memory:');
    try {
      final files = backup['attachments'] as Map;
      final fileId = files.keys.single as String;
      final ciphertext = base64Decode(files[fileId] as String);
      store.putAttachment(fileId, ciphertext);
      for (final row in sourceRows) {
        store.save(
          row['id'] as String,
          Map<String, dynamic>.from(row['ciphertext'] as Map),
          false,
          'new-${row['id']}',
          attachments: [fileId],
        );
      }
      store.close();
      store = LocalStore(path);
      expect(store.pending, hasLength(3));
      expect(store.pendingAttachments, hasLength(1));
      expect(store.attachment(fileId), ciphertext);
      final table = jsonEncode(store.records.map((r) => r.toJson()).toList());
      expect(table.contains('虚构的私密奖状'), isFalse);
      expect(table.contains('私密原件.pdf'), isFalse);
      for (final row in sourceRows) {
        expect(store.get(row['id'] as String)!.ciphertext, row['ciphertext']);
      }
      final remote = MaterialRemote();
      final engine = SyncEngine(store, remote);
      await expectLater(engine.run(), throwsStateError);
      expect(store.pending, hasLength(3));
      remote.offline = false;
      await engine.run();
      expect(remote.operations, ['file', 'record', 'record', 'record']);
      expect(remote.files[fileId], ciphertext);
      await SyncEngine(otherDevice, remote).run();
      final materialId = sourceRows[1]['id'] as String;
      otherDevice.save(
        materialId,
        store.get(materialId)!.ciphertext,
        false,
        'offline-material-edit',
        attachments: [fileId],
      );
      // Tombstone payload is opaque to the storage/sync layer.
      store.save(
        materialId,
        store.get(materialId)!.ciphertext,
        true,
        'delete-material',
      );
      await engine.run();
      await SyncEngine(otherDevice, remote).run();
      expect(otherDevice.get(materialId)!.deleted, isFalse);
      expect(otherDevice.conflicts[materialId]!.deleted, isTrue);
      expect(otherDevice.pending, isEmpty);
      otherDevice.resolve(
        materialId,
        useLocal: false,
        mutationId: 'accept-delete',
      );
      expect(otherDevice.get(materialId)!.deleted, isTrue);
      expect(store.attachment(fileId), ciphertext);
      expect(
        store.get(sourceRows[2]['id'] as String)!.ciphertext,
        sourceRows[2]['ciphertext'],
      );
    } finally {
      store.close();
      otherDevice.close();
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File('$path$suffix');
        if (await file.exists()) await file.delete();
      }
      await directory.delete();
    }
  });
}
