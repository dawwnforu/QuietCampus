import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';

import 'archive_actions.dart';
import 'backup_archive.dart';
import 'model.dart';
import 'snapshot_store.dart';
import 'vault_crypto.dart';

/// Browser-local adapter for the original archive UI, models and cipher format.
/// It never creates a Supabase client or sends a record to a server.
class BrowserArchiveController extends ArchiveActions {
  BrowserArchiveController(this.storage, this.sodium);
  final SnapshotStore storage;
  final SodiumSumo sodium;
  static const _uuid = Uuid();
  BackupArchive? _archive;
  VaultCrypto? _vault;
  int _revision = 0;
  bool _writing = false;
  bool ready = false;
  bool hasStoredData = false;
  bool stale = false;
  String? failure;
  final _draftFiles = <String, Uint8List>{};
  Map<String, Entry?> _conflictEntries = {};

  @override
  List<Entry> entries = [];
  bool get needsSetup => ready && !hasStoredData && failure == null;
  int get storageRevision => _revision;
  @override
  bool get unlocked => _vault != null;
  @override
  String get syncActionLabel => '检查此浏览器的其他页面更新';
  @override
  String get deletionNotice => '删除只影响此浏览器档案。导出过的备份不会自动删除，也不包含云端同步。';
  @override
  String get syncStatus => stale
      ? '另一个页面有新版本 · 当前内容仍保留'
      : unlocked
      ? '已加密保存在此浏览器 · 不上传云端'
      : '浏览器本地加密档案';
  @override
  String get notificationWarning => '';
  @override
  bool get notificationsEnabled => false;
  @override
  Future<bool> enableNotifications(bool enabled) async => false;
  @override
  Map<String, SealedRecord> get conflicts => _archive?.conflicts ?? const {};
  @override
  Entry? conflictEntry(String id) => _conflictEntries[id];
  @override
  Entry? entry(String id) => entries.where((e) => e.id == id).firstOrNull;
  SealedRecord? _row(String id) =>
      _archive?.records.where((r) => r.id == id).firstOrNull;
  @override
  int revisionOf(String id) => _row(id)?.generation ?? 0;
  @override
  bool isDeleted(String id) => _row(id)?.deleted ?? false;

  Future<void> load() async {
    if (unlocked || _writing) throw StateError('请先保存并锁定当前档案');
    ready = false;
    failure = null;
    try {
      final stored = await storage.read();
      hasStoredData = stored != null;
      _archive = stored == null ? null : BackupArchive.decode(stored.bytes);
      _revision = stored?.revision ?? 0;
      stale = false;
    } catch (_) {
      failure = '无法读取本地档案，原资料未清除。请保留站点数据并重试或从备份恢复。';
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<String> createVault(String password) async {
    if (!needsSetup || _writing) throw StateError('已有档案不能重新初始化，请先解锁或使用恢复入口');
    final owner = _uuid.v4();
    final created = await VaultCrypto.create(sodium, owner, password);
    try {
      final initial = BackupArchive.decode(
        _encode({
          'format': 'quiet-campus-backup',
          'v': 1,
          'owner': owner,
          'vault': {
            'owner_id': owner,
            'envelope': created.header,
            'revision': 1,
          },
          'records': [],
          'conflicts': <String, dynamic>{},
          'attachments': <String, dynamic>{},
        }),
      );
      await _commit(initial);
      _vault = created.vault;
      entries = [];
      notifyListeners();
      return created.recovery;
    } catch (_) {
      created.vault.dispose();
      rethrow;
    }
  }

  Future<void> unlock(String secret, {bool recovery = false}) async {
    if (_archive == null || unlocked) throw StateError('请先打开已有档案');
    final opened = await _archive!.unlock(sodium, secret, recovery: recovery);
    _adopt(opened);
  }

  void _adopt(OpenedBackup opened) {
    if (!identical(_vault, opened.vault)) _vault?.dispose();
    _vault = opened.vault;
    _archive = opened.archive;
    entries = [...opened.entries]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _conflictEntries = {...opened.conflicts};
    hasStoredData = true;
    failure = null;
    stale = false;
    notifyListeners();
  }

  void lock() {
    _vault?.dispose();
    _vault = null;
    entries = [];
    _conflictEntries = {};
    _draftFiles.clear();
    notifyListeners();
  }

  static Uint8List _encode(Map<String, dynamic> json) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('浏览器版加密档案上限为 64 MiB，原资料未改动');
    }
    return bytes;
  }

  Future<void> _commit(BackupArchive candidate, {int? expectedRevision}) async {
    if (_writing) throw StateError('上一笔保存尚未完成，请保留输入后重试');
    _writing = true;
    try {
      final revision = await storage.commit(
        _encode(candidate.toJson()),
        baseRevision: expectedRevision ?? _revision,
      );
      _revision = revision;
      _archive = candidate;
      hasStoredData = true;
      stale = false;
    } finally {
      _writing = false;
    }
  }

  BackupArchive _changed({
    List<SealedRecord>? records,
    Map<String, SealedRecord>? conflicts,
    Map<String, Uint8List>? files,
    Map<String, dynamic>? vault,
  }) => BackupArchive.decode(
    _encode({
      ..._archive!.toJson(),
      if (records != null) 'records': records.map((r) => r.toJson()).toList(),
      if (conflicts != null)
        'conflicts': {
          for (final pair in conflicts.entries) pair.key: pair.value.toJson(),
        },
      if (files != null)
        'attachments': {
          for (final pair in files.entries) pair.key: base64Encode(pair.value),
        },
      'vault': ?vault,
    }),
  );

  void _checkUnlocked() {
    if (!unlocked || _archive == null) throw StateError('档案已锁定，请先解锁');
    if (stale) throw StateError('其他页面已有新版本，请先复制未保存内容、导出备份，再重新打开最新资料');
  }

  @override
  Future<void> save(Entry entry, {required int baseRevision}) async {
    _checkUnlocked();
    if (revisionOf(entry.id) != baseRevision || conflicts.containsKey(entry.id)) {
      throw StateError('记录有新版本或冲突，请保留输入后重新打开');
    }
    Entry.fromJson(entry.id, entry.toJson());
    Document.fromJson(entry.delta);
    for (final op in entry.delta) {
      if (op is! Map ||
          (op['insert'] is! String && materialReference(op['insert']) == null)) {
        throw const FormatException('不支持的富文本块，原资料未改动');
      }
    }
    if (!['profile', 'tag_catalog'].contains(entry.kind)) {
      await rememberTags(entry.tags);
    }
    _checkUnlocked();
    final files = {..._archive!.files};
    for (final file in entry.attachments) {
      final data = _draftFiles[file.id] ?? files[file.id];
      if (data == null) throw StateError('附件尚未准备好，输入仍保留');
      final plain = _vault!.openAttachment(file.id, data);
      try {
        if (plain.length != file.size) throw const FormatException('附件大小不一致');
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
      files[file.id] = data;
    }
    final previous = _row(entry.id);
    final row = SealedRecord(
      id: entry.id,
      revision: previous?.revision ?? 0,
      ciphertext: _vault!.sealJson(entry.id, entry.toJson()),
      deleted: false,
      dirty: true,
      generation: baseRevision + 1,
      mutationId: _uuid.v4(),
    );
    final candidate = _changed(
      records: [row, ..._archive!.records.where((r) => r.id != row.id)],
      files: files,
    );
    await _commit(candidate);
    entries = [entry, ...entries.where((e) => e.id != entry.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final file in entry.attachments) {
      _draftFiles.remove(file.id);
    }
    notifyListeners();
  }

  @override
  Future<void> deleteEntry(Entry entry) async {
    _checkUnlocked();
    if (conflicts.containsKey(entry.id)) throw StateError('请先处理这条记录的版本冲突');
    await rememberTags(entry.tags);
    final previous = _row(entry.id);
    final tombstone = SealedRecord(
      id: entry.id,
      revision: previous?.revision ?? 0,
      ciphertext: _vault!.sealJson(entry.id, {'v': 1, 'deleted': true}),
      deleted: true,
      dirty: true,
      generation: (previous?.generation ?? 0) + 1,
      mutationId: _uuid.v4(),
    );
    await _commit(
      _changed(
        records: [
          tombstone,
          ..._archive!.records.where((r) => r.id != entry.id),
        ],
      ),
    );
    entries = entries.where((e) => e.id != entry.id).toList();
    notifyListeners();
  }

  @override
  Future<Attachment> addAttachment(String name, Uint8List bytes) async {
    _checkUnlocked();
    if (bytes.length > BackupArchive.maxAttachmentBytes) {
      throw const FormatException('附件不能超过 20 MiB');
    }
    if (_draftFiles.values.fold<int>(
          bytes.length,
          (sum, data) => sum + data.length,
        ) >
        maxArchiveBytes) {
      throw const FormatException('未保存的附件过多，请先保存当前记录');
    }
    final id = _uuid.v4();
    _draftFiles[id] = _vault!.sealAttachment(id, bytes);
    return Attachment(id: id, name: name, size: bytes.length);
  }

  @override
  Future<Uint8List> readAttachment(Attachment file) async {
    if (!unlocked) throw StateError('档案已锁定');
    final data = _draftFiles[file.id] ?? _archive!.files[file.id];
    if (data == null) throw StateError('附件不存在，原资料未改动');
    return _vault!.openAttachment(file.id, data);
  }

  @override
  Future<void> sync() async {
    if (!ready || _writing) return;
    final latest = await storage.read();
    stale = (latest?.revision ?? 0) != _revision;
    notifyListeners();
  }

  Future<Uint8List> backup() async {
    if (!unlocked) throw StateError('请先解锁后导出备份');
    return _encode(_archive!.toJson());
  }

  /// The UI must preview and confirm replacement after exporting its old data.
  /// On success the controller owns the opened key; on failure the caller does.
  Future<bool> restore(
    OpenedBackup candidate, {
    required int expectedRevision,
  }) async {
    if (!ready || failure != null) throw StateError('请先重试打开本地存储，不能覆盖读取失败的资料');
    if (_archive != null &&
        listEquals(
          _encode(_archive!.toJson()),
          _encode(candidate.archive.toJson()),
        )) {
      final latest = await storage.read();
      if ((latest?.revision ?? 0) != expectedRevision) {
        throw StateError('恢复预览后本地资料已变化，请重新预览');
      }
      candidate.dispose();
      return false;
    }
    await _commit(candidate.archive, expectedRevision: expectedRevision);
    _draftFiles.clear();
    _adopt(candidate);
    return true;
  }

  Future<String> changePassword(String password) async {
    _checkUnlocked();
    final wrapped = await _vault!.wrap(password);
    await _commit(
      _changed(
        vault: {
          ..._archive!.vaultRow,
          'envelope': wrapped.header,
          'revision': (_archive!.vaultRow['revision'] as int) + 1,
        },
      ),
    );
    notifyListeners();
    return wrapped.recovery;
  }

  @override
  Future<void> resolve(String id, bool useLocal) async {
    _checkUnlocked();
    final remote = conflicts[id];
    final local = _row(id);
    if (remote == null || local == null) throw StateError('冲突已变化，请重新打开');
    final selected = useLocal ? local : remote;
    final row = SealedRecord(
      id: id,
      revision: remote.revision,
      ciphertext: selected.ciphertext,
      deleted: selected.deleted,
      dirty: useLocal,
      generation: local.generation + 1,
      mutationId: _uuid.v4(),
    );
    final nextConflicts = {...conflicts}..remove(id);
    await _commit(
      _changed(
        records: [row, ..._archive!.records.where((r) => r.id != id)],
        conflicts: nextConflicts,
      ),
    );
    final value = useLocal ? entry(id) : _conflictEntries[id];
    entries = [?value, ...entries.where((e) => e.id != id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _conflictEntries.remove(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _vault?.dispose();
    _draftFiles.clear();
    super.dispose();
  }
}
