import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'model.dart';

class LocalStore {
  LocalStore(String path) : db = sqlite3.open(path) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL)''',
    );
    db.execute('''CREATE TABLE IF NOT EXISTS records(
      id TEXT PRIMARY KEY, revision INTEGER NOT NULL, ciphertext TEXT NOT NULL,
      deleted INTEGER NOT NULL, dirty INTEGER NOT NULL, generation INTEGER NOT NULL,
      mutation TEXT NOT NULL)''');
    db.execute(
      '''CREATE TABLE IF NOT EXISTS conflicts(id TEXT PRIMARY KEY, remote TEXT NOT NULL)''',
    );
    db.execute(
      '''CREATE TABLE IF NOT EXISTS attachments(
      id TEXT PRIMARY KEY, ciphertext BLOB NOT NULL, uploaded INTEGER NOT NULL, ready INTEGER NOT NULL)''',
    );
  }
  final Database db;
  bool get hasArchiveData => db.select('''
    SELECT 1 FROM records UNION ALL SELECT 1 FROM conflicts
    UNION ALL SELECT 1 FROM attachments LIMIT 1
  ''').isNotEmpty;

  void restoreEmpty({
    required List<SealedRecord> records,
    required Map<String, SealedRecord> conflicts,
    required Map<String, Uint8List> attachments,
  }) {
    db.execute('BEGIN IMMEDIATE');
    try {
      if (hasArchiveData) {
        throw StateError('本机已有档案，不能整体恢复；原资料已保留。');
      }
      for (final record in records) {
        db.execute('INSERT INTO records VALUES(?,?,?,?,?,?,?)', [
          record.id,
          record.revision,
          jsonEncode(record.ciphertext),
          record.deleted ? 1 : 0,
          record.dirty ? 1 : 0,
          record.generation,
          record.mutationId,
        ]);
      }
      for (final pair in conflicts.entries) {
        db.execute('INSERT INTO conflicts VALUES(?,?)', [
          pair.key,
          pair.value.encode(),
        ]);
      }
      for (final pair in attachments.entries) {
        // Re-upload authenticated ciphertext before any restored outbox entry.
        db.execute('INSERT INTO attachments VALUES(?,?,0,1)', [
          pair.key,
          pair.value,
        ]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  String? meta(String key) =>
      db.select('SELECT v FROM meta WHERE k=?', [key]).firstOrNull?['v']
          as String?;
  void setMeta(String key, String value) =>
      db.execute('INSERT OR REPLACE INTO meta VALUES(?,?)', [key, value]);

  SealedRecord _read(Row r) => SealedRecord(
    id: r['id'] as String,
    revision: r['revision'] as int,
    ciphertext: jsonDecode(r['ciphertext'] as String) as Map<String, dynamic>,
    deleted: r['deleted'] == 1,
    dirty: r['dirty'] == 1,
    generation: r['generation'] as int,
    mutationId: r['mutation'] as String,
  );
  List<SealedRecord> get records =>
      db.select('SELECT * FROM records').map(_read).toList();
  SealedRecord? get(String id) => db
      .select('SELECT * FROM records WHERE id=?', [id])
      .map(_read)
      .firstOrNull;
  List<SealedRecord> get pending => db
      .select(
        'SELECT * FROM records WHERE dirty=1 AND id NOT IN (SELECT id FROM conflicts)',
      )
      .map(_read)
      .toList();
  Map<String, SealedRecord> get conflicts => {
    for (final r in db.select('SELECT * FROM conflicts'))
      r['id'] as String: SealedRecord.fromRemote(
        jsonDecode(r['remote'] as String) as Map<String, dynamic>,
      ),
  };

  void _put(SealedRecord r) =>
      db.execute('INSERT OR REPLACE INTO records VALUES(?,?,?,?,?,?,?)', [
        r.id,
        r.revision,
        jsonEncode(r.ciphertext),
        r.deleted ? 1 : 0,
        r.dirty ? 1 : 0,
        r.generation,
        r.mutationId,
      ]);

  void save(
    String id,
    Map<String, dynamic> envelope,
    bool deleted,
    String mutationId, {
    List<String> attachments = const [],
  }) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final old = get(id);
      _put(
        SealedRecord(
          id: id,
          revision: old?.revision ?? 0,
          ciphertext: envelope,
          deleted: deleted,
          dirty: true,
          generation: (old?.generation ?? 0) + 1,
          mutationId: mutationId,
        ),
      );
      for (final attachment in attachments) {
        db.execute('UPDATE attachments SET ready=1 WHERE id=?', [attachment]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void acknowledge(SealedRecord sent, int revision) {
    // A newer local edit must survive the acknowledgement of an older upload.
    db.execute(
      'UPDATE records SET revision=max(revision,?), dirty=CASE WHEN generation=? THEN 0 ELSE 1 END WHERE id=?',
      [revision, sent.generation, sent.id],
    );
  }

  void acceptRemote(SealedRecord remote) {
    final local = get(remote.id);
    if (local == null || (!local.dirty && remote.revision > local.revision)) {
      _put(remote);
    } else if (local.dirty && remote.revision > local.revision) {
      conflict(remote);
    }
  }

  void conflict(SealedRecord remote) => db.execute(
    'INSERT OR REPLACE INTO conflicts VALUES(?,?)',
    [remote.id, remote.encode()],
  );

  void resolve(
    String id, {
    required bool useLocal,
    required String mutationId,
  }) {
    final remote = conflicts[id]!;
    db.execute('BEGIN IMMEDIATE');
    try {
      if (useLocal) {
        db.execute(
          'UPDATE records SET revision=?, dirty=1, generation=generation+1, mutation=? WHERE id=?',
          [remote.revision, mutationId, id],
        );
      } else {
        _put(remote);
      }
      db.execute('DELETE FROM conflicts WHERE id=?', [id]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void putAttachment(String id, Uint8List bytes, {bool uploaded = false}) =>
      db.execute('INSERT OR REPLACE INTO attachments VALUES(?,?,?,?)', [
        id,
        bytes,
        uploaded ? 1 : 0,
        uploaded ? 1 : 0,
      ]);
  Uint8List? attachment(String id) =>
      db.select('SELECT ciphertext FROM attachments WHERE id=?', [
            id,
          ]).firstOrNull?['ciphertext']
          as Uint8List?;
  Map<String, Uint8List> get pendingAttachments => {
    for (final r in db.select(
      'SELECT * FROM attachments WHERE uploaded=0 AND ready=1',
    ))
      r['id'] as String: r['ciphertext'] as Uint8List,
  };
  void uploaded(String id) =>
      db.execute('UPDATE attachments SET uploaded=1 WHERE id=?', [id]);
  void close() => db.close();
}
