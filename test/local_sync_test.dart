import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/local_store.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/sync_engine.dart';

const envelope = <String, dynamic>{
  'v': 1,
  'nonce': 'nonce',
  'box': 'encrypted',
};
SealedRecord remote(int revision, {bool deleted = false}) => SealedRecord(
  id: 'note',
  revision: revision,
  ciphertext: envelope,
  deleted: deleted,
);

class MemoryRemote implements SyncRemote {
  int revision = 0;
  bool deleted = false;
  bool offline = false;
  bool loseResponse = false;
  void Function()? duringUpload;
  void Function()? duringWrite;
  final acknowledgements = <String, Map<String, dynamic>>{};
  final attachments = <String>[];
  @override
  Future<void> upload(String id, Uint8List bytes) async {
    if (offline) throw StateError('offline');
    attachments.add(id);
    duringUpload?.call();
    duringUpload = null;
  }

  @override
  Future<Map<String, dynamic>> write(SealedRecord record) async {
    if (offline) throw StateError('offline');
    if (acknowledgements.containsKey(record.mutationId)) {
      return acknowledgements[record.mutationId]!;
    }
    if (record.revision != revision) {
      return {
        'conflict': true,
        'record': remote(revision, deleted: deleted).toJson(),
      };
    }
    revision++;
    deleted = record.deleted;
    final response = <String, dynamic>{
      'conflict': false,
      'record': {'revision': revision},
    };
    acknowledgements[record.mutationId] = response;
    duringWrite?.call();
    duringWrite = null;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('connection lost after commit');
    }
    return response;
  }

  @override
  Future<List<SealedRecord>> readAll() async {
    if (offline) throw StateError('offline');
    return revision == 0 ? [] : [remote(revision, deleted: deleted)];
  }
}

void main() {
  late LocalStore store;
  setUp(() => store = LocalStore(':memory:'));
  tearDown(() => store.close());

  test('an acknowledgement cannot discard a newer edit', () {
    store.save('note', envelope, false, 'mutation-1');
    final sent = store.pending.single;
    store.save('note', {'box': 'newer'}, false, 'mutation-2');
    store.acknowledge(sent, 1);
    expect(store.get('note')!.revision, 1);
    expect(store.pending.single.ciphertext['box'], 'newer');
  });

  test('remote delete retains offline edit until explicit resolution', () {
    store.acceptRemote(remote(1));
    store.save('note', envelope, false, 'local');
    store.acceptRemote(remote(2, deleted: true));
    expect(store.get('note')!.deleted, false);
    expect(store.conflicts['note']!.deleted, true);
    expect(store.pending, isEmpty);
    store.resolve('note', useLocal: true, mutationId: 'restore');
    expect(store.pending.single.revision, 2);
    expect(store.pending.single.deleted, false);
  });

  test('accepting a remote delete clears the pending edit', () {
    store.save('note', envelope, false, 'local');
    store.conflict(remote(2, deleted: true));
    store.resolve('note', useLocal: false, mutationId: 'unused');
    expect(store.get('note')!.deleted, true);
    expect(store.pending, isEmpty);
  });

  test('offline retry uploads encrypted attachments before records', () async {
    final server = MemoryRemote()..offline = true;
    final engine = SyncEngine(store, server);
    store.putAttachment('proof', Uint8List.fromList([1, 2, 3]));
    store.save('note', envelope, false, 'first', attachments: ['proof']);
    await expectLater(engine.run(), throwsStateError);
    expect(store.pending, hasLength(1));
    server.offline = false;
    await engine.run();
    expect(server.attachments, ['proof']);
    expect(store.pending, isEmpty);
    expect(store.get('note')!.revision, 1);
  });

  test('a lost response is retried without a false version conflict', () async {
    final server = MemoryRemote()..loseResponse = true;
    final engine = SyncEngine(store, server);
    store.save('note', envelope, false, 'same-id');
    await expectLater(engine.run(), throwsStateError);
    await engine.run();
    expect(server.revision, 1);
    expect(store.pending, isEmpty);
    expect(store.conflicts, isEmpty);
  });

  test('editing during upload leaves the next generation pending', () async {
    final server = MemoryRemote();
    final engine = SyncEngine(store, server);
    store.save('note', envelope, false, 'one');
    server.duringWrite = () => store.save('note', envelope, false, 'two');
    await engine.run();
    expect(store.pending.single.revision, 1);
    await engine.run();
    expect(server.revision, 2);
    expect(store.pending, isEmpty);
  });

  test(
    'cancelled attachment drafts do not get uploaded by the timer',
    () async {
      final server = MemoryRemote();
      store.putAttachment('draft', Uint8List.fromList([1, 2, 3]));
      await SyncEngine(store, server).run();
      expect(server.attachments, isEmpty);
    },
  );

  test(
    'an edit made during attachment upload waits for its own attachment',
    () async {
      final server = MemoryRemote();
      final engine = SyncEngine(store, server);
      store.putAttachment('first-proof', Uint8List.fromList([1]));
      store.save('note', envelope, false, 'one', attachments: ['first-proof']);
      server.duringUpload = () {
        store.putAttachment('second-proof', Uint8List.fromList([2]));
        store.save(
          'note',
          envelope,
          false,
          'two',
          attachments: ['second-proof'],
        );
      };
      await engine.run();
      expect(server.attachments, ['first-proof']);
      expect(store.pending.single.mutationId, 'two');
      await engine.run();
      expect(server.attachments, ['first-proof', 'second-proof']);
      expect(store.pending, isEmpty);
    },
  );

  test('late acknowledgement cannot rewind a resolved conflict', () {
    store.acceptRemote(remote(1));
    store.save('note', envelope, false, 'one');
    final sent = store.pending.single;
    store.conflict(remote(3));
    store.resolve('note', useLocal: true, mutationId: 'resolved');
    store.acknowledge(sent, 2);
    expect(store.pending.single.revision, 3);
  });
}
