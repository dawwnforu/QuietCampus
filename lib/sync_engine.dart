import 'dart:typed_data';

import 'local_store.dart';
import 'model.dart';

abstract interface class SyncRemote {
  Future<void> upload(String id, Uint8List ciphertext);
  Future<Map<String, dynamic>> write(SealedRecord record);
  Future<List<SealedRecord>> readAll();
}

class SyncEngine {
  SyncEngine(this.store, this.remote);
  final LocalStore store;
  final SyncRemote remote;
  Future<void>? _running;
  bool _again = false;
  bool _stopped = false;

  Future<void> run() async {
    if (_stopped) return;
    _again = true;
    if (_running != null) return _running!;
    _running = _drain();
    try {
      await _running;
    } finally {
      _running = null;
    }
  }

  Future<void> _drain() async {
    do {
      _again = false;
      final pendingRecords = store.pending;
      for (final attachment in store.pendingAttachments.entries) {
        if (_stopped) return;
        await remote
            .upload(attachment.key, attachment.value)
            .timeout(const Duration(seconds: 30));
        store.uploaded(attachment.key);
      }
      for (final record in pendingRecords) {
        if (_stopped) return;
        final result = await remote
            .write(record)
            .timeout(const Duration(seconds: 30));
        if (result['conflict'] == true) {
          if (result['record'] == null) throw StateError('云端版本缺失，本机内容已保留');
          store.conflict(
            SealedRecord.fromRemote(
              Map<String, dynamic>.from(result['record'] as Map),
            ),
          );
        } else {
          store.acknowledge(
            record,
            (result['record'] as Map)['revision'] as int,
          );
        }
      }
      if (_stopped) return;
      for (final record in await remote.readAll().timeout(
        const Duration(seconds: 30),
      )) {
        store.acceptRemote(record);
      }
    } while (_again && !_stopped);
  }

  Future<void> stop() async {
    _stopped = true;
    try {
      await _running;
    } catch (_) {
      /* Pending ciphertext remains on disk. */
    }
  }
}
