import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'cloud.dart';
import 'archive_actions.dart';
import 'backup_archive.dart';
import 'local_store.dart';
import 'model.dart';
import 'reminders.dart';
import 'sync_engine.dart';
import 'vault_crypto.dart';

class ArchiveController extends ArchiveActions {
  ArchiveController(this.client, this.sodium, this.secure, this.reminders);
  final SupabaseClient client;
  final SodiumSumo sodium;
  final FlutterSecureStorage secure;
  final Reminders reminders;
  @override
  String get notificationWarning => reminders.warning;
  static const uuid = Uuid();
  LocalStore? store;
  Cloud? cloud;
  SyncEngine? engine;
  VaultCrypto? vault;
  Map<String, dynamic>? header;
  int headerRevision = 0;
  String? owner;
  String? failure;
  @override
  String syncStatus = '尚未同步';
  bool loading = false;
  bool accountReady = false;
  @override
  bool notificationsEnabled = false;
  bool _closing = false;
  RealtimeChannel? _channel;
  Timer? _timer;
  @override
  List<Entry> entries = [];

  @override
  bool get unlocked => vault != null;
  @override
  bool isDeleted(String id) => store?.get(id)?.deleted == true;
  bool get needsSetup => accountReady && header == null;
  bool get canRestoreBackup =>
      accountReady &&
      !unlocked &&
      header != null &&
      store != null &&
      !store!.hasArchiveData;
  String get email => client.auth.currentUser?.email ?? '';
  @override
  Map<String, SealedRecord> get conflicts => store?.conflicts ?? {};
  @override
  int revisionOf(String id) => store?.get(id)?.revision ?? 0;
  @override
  Entry? entry(String id) => entries.where((e) => e.id == id).firstOrNull;

  Future<void> refreshSession() async {
    if (client.auth.currentUser == null) {
      if (owner != null && !_closing) await _close();
      notifyListeners();
    } else {
      await openAccount();
    }
  }

  Future<void> openAccount() async {
    final id = client.auth.currentUser?.id;
    if (id == null || loading || (owner == id && accountReady)) return;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      if (owner != null && owner != id) await _close();
      owner = id;
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      store ??= LocalStore(p.join(dir.path, '$id.sqlite'));
      cloud = Cloud(client, id);
      final cached = store!.meta('vault');
      if (cached != null) {
        final row = jsonDecode(cached) as Map<String, dynamic>;
        header = Map<String, dynamic>.from(row['envelope'] as Map);
        headerRevision = row['revision'] as int;
      }
      try {
        final row = await cloud!.vault().timeout(const Duration(seconds: 12));
        if (row != null) {
          _cacheHeader(row);
        } else if (cached != null) {
          throw StateError('云端档案不可访问，请确认账号状态');
        }
      } catch (_) {
        if (cached == null) rethrow;
      }
      notificationsEnabled = store!.meta('notifications') == 'true';
      accountReady = true;
    } catch (_) {
      failure = '暂时无法连接账号。首次使用需要联网；已有档案不会被清除。';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _cacheHeader(Map<String, dynamic> row) {
    store!.setMeta('vault', jsonEncode(row));
    header = Map<String, dynamic>.from(row['envelope'] as Map);
    headerRevision = row['revision'] as int;
  }

  Future<String> createVault(String password) async {
    final created = await VaultCrypto.create(sodium, owner!, password);
    try {
      final row = await cloud!.putVault(created.header, 0);
      _cacheHeader(row);
      vault = created.vault;
      await _activated();
      return created.recovery;
    } catch (_) {
      if (vault == created.vault) {
        vault = null;
        entries = [];
      }
      created.vault.dispose();
      rethrow;
    }
  }

  Future<void> unlock(String secret, {bool recovery = false}) async {
    final unlockedVault = await VaultCrypto.unlock(
      sodium,
      owner!,
      header!,
      secret,
      recovery: recovery,
    );
    vault = unlockedVault;
    try {
      await _activated();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  Future<void> unlockDevice() async {
    final value = await secure.read(key: 'quiet-campus.vault.$owner');
    if (value == null) throw StateError('此设备没有保存密钥，请使用口令或恢复密钥');
    final raw = base64Decode(value);
    try {
      vault = VaultCrypto(sodium, owner!, sodium.secureCopy(raw));
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
    try {
      await _activated();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  void _checkBackupTarget(BackupArchive archive) {
    if (!canRestoreBackup || _closing || owner != archive.owner) {
      throw StateError('只能恢复到同账号的本机空档案；原资料未改动。');
    }
    final other = archive.vaultRow['envelope'] as Map;
    // shortcut: Changed envelopes need a separate old/current-key flow before import.
    if (![
          'v',
          'salt',
          'ops',
          'mem',
        ].every((key) => header![key] == other[key]) ||
        !mapEquals(header!['pass'] as Map, other['pass'] as Map) ||
        !mapEquals(header!['recovery'] as Map, other['recovery'] as Map)) {
      throw StateError('此备份的密钥封装与当前账号不同；请保留备份，不会覆盖当前档案。');
    }
  }

  Future<OpenedBackup> verifyBackup(
    BackupArchive archive,
    String secret, {
    bool recovery = false,
  }) async {
    _checkBackupTarget(archive);
    final opened = await archive.unlock(sodium, secret, recovery: recovery);
    try {
      _checkBackupTarget(archive);
      return opened;
    } catch (_) {
      opened.dispose();
      rethrow;
    }
  }

  Future<void> restoreBackup(OpenedBackup opened) async {
    _checkBackupTarget(opened.archive);
    await engine?.stop();
    engine = null;
    _checkBackupTarget(opened.archive);
    store!.restoreEmpty(
      records: opened.archive.records,
      conflicts: opened.archive.conflicts,
      attachments: opened.archive.files,
    );
    syncStatus = '备份已保存到本机 · 解锁后再与云端对账';
    notifyListeners();
  }

  Future<void> _activated() async {
    final raw = vault!.master.extractBytes();
    try {
      await secure.write(
        key: 'quiet-campus.vault.$owner',
        value: base64Encode(raw),
      );
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
    _refresh();
    engine ??= SyncEngine(store!, cloud!);
    _channel ??= cloud!.subscribe(() => unawaited(sync()));
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sync()),
    );
    notifyListeners();
    unawaited(sync());
  }

  Future<String> changePassword(String password) async {
    final wrapped = await vault!.wrap(password);
    final row = await cloud!.putVault(wrapped.header, headerRevision);
    _cacheHeader(row);
    return wrapped.recovery;
  }

  void lock() {
    vault?.dispose();
    vault = null;
    entries = [];
    notifyListeners();
  }

  void _refresh() {
    if (vault == null) return;
    // Decrypt into memory only; no persistent plaintext search index.
    entries =
        store!.records
            .where((r) => !r.deleted)
            .map(
              (r) => Entry.fromJson(r.id, vault!.openJson(r.id, r.ciphertext)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> sync() async {
    if (_closing || engine == null || !unlocked) return;
    syncStatus = '正在同步';
    notifyListeners();
    try {
      await engine!.run();
      if (_closing || !unlocked) return;
      _refresh();
      syncStatus = conflicts.isEmpty ? '已与云端同步' : '有 ${conflicts.length} 项版本冲突';
    } on FormatException catch (error) {
      syncStatus = '${error.message} · 原始密文已保留';
    } catch (_) {
      syncStatus = '连接暂不可用 · 本机修改已保留';
    }
    if (!_closing && unlocked) {
      try {
        await reminders.reconcile(entries, enabled: notificationsEnabled);
      } catch (_) {
        reminders.warning = '系统提醒暂不可用，请查看今天的待办。';
      }
      notifyListeners();
    }
  }

  @override
  Future<void> save(Entry entry, {required int baseRevision}) async {
    if (!['profile', 'tag_catalog'].contains(entry.kind)) {
      await rememberTags(entry.tags);
    }
    final envelope = vault!.sealJson(entry.id, entry.toJson());
    if (utf8.encode(jsonEncode(envelope)).length > 2 * 1024 * 1024) {
      throw const FormatException('这条记录过长，请拆成多条；图片请作为附件保存');
    }
    final old = store!.get(entry.id);
    if (old != null && old.revision != baseRevision) store!.conflict(old);
    store!.save(
      entry.id,
      envelope,
      false,
      uuid.v4(),
      attachments: entry.attachments.map((a) => a.id).toList(),
    );
    _refresh();
    notifyListeners();
    try {
      await reminders.reconcile(entries, enabled: notificationsEnabled);
    } catch (_) {
      reminders.warning = '记录已保存，系统提醒暂不可用。';
    }
    unawaited(sync());
  }

  @override
  Future<void> deleteEntry(Entry entry) async {
    await rememberTags(entry.tags);
    // shortcut: keep orphan attachment ciphertext until account deletion; add reference-aware GC when device history can prove it is unused.
    store!.save(
      entry.id,
      vault!.sealJson(entry.id, {'v': 1, 'deleted': true}),
      true,
      uuid.v4(),
    );
    _refresh();
    notifyListeners();
    try {
      await reminders.reconcile(entries, enabled: notificationsEnabled);
    } catch (_) {
      reminders.warning = '删除已保存，系统提醒暂不可用。';
    }
    unawaited(sync());
  }

  @override
  Future<void> resolve(String id, bool useLocal) async {
    store!.resolve(id, useLocal: useLocal, mutationId: uuid.v4());
    _refresh();
    notifyListeners();
    unawaited(sync());
  }

  @override
  Entry? conflictEntry(String id) {
    final row = conflicts[id]!;
    return row.deleted
        ? null
        : Entry.fromJson(id, vault!.openJson(id, row.ciphertext));
  }

  @override
  Future<Attachment> addAttachment(String name, Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('单个附件最多 20 MiB');
    }
    final id = uuid.v4();
    store!.putAttachment(id, vault!.sealAttachment(id, bytes));
    return Attachment(id: id, name: p.basename(name), size: bytes.length);
  }

  Future<Uint8List> _encryptedAttachment(String id) async {
    final activeStore = store!;
    final activeCloud = cloud!;
    final local = activeStore.attachment(id);
    if (local != null) return local;
    final downloaded = await activeCloud.download(id);
    if (store != activeStore || cloud != activeCloud || !unlocked) {
      throw StateError('档案已锁定或账号已切换');
    }
    activeStore.putAttachment(id, downloaded, uploaded: true);
    return downloaded;
  }

  @override
  Future<Uint8List> readAttachment(Attachment file) async {
    final activeVault = vault;
    if (activeVault == null) throw StateError('档案已锁定');
    final bytes = await _encryptedAttachment(file.id);
    if (vault != activeVault) throw StateError('档案已锁定');
    return activeVault.openAttachment(file.id, bytes);
  }

  Future<Uint8List> backup() async {
    final activeStore = store;
    final activeVault = vault;
    final activeCloud = cloud;
    final activeOwner = owner;
    if (activeStore == null || activeVault == null || activeOwner == null) {
      throw StateError('档案已锁定');
    }
    void checkAccount() {
      if (_closing ||
          store != activeStore ||
          vault != activeVault ||
          cloud != activeCloud ||
          owner != activeOwner) {
        throw StateError('档案已锁定或账号已切换');
      }
    }

    await sync();
    checkAccount();
    final snapshotRecords = activeStore.records;
    final snapshotConflicts = activeStore.conflicts;
    final references = <String>{};
    for (final row in snapshotRecords.where((r) => !r.deleted)) {
      final e = Entry.fromJson(
        row.id,
        activeVault.openJson(row.id, row.ciphertext),
      );
      references.addAll(e.attachments.map((a) => a.id));
    }
    for (final row in snapshotConflicts.values.where((r) => !r.deleted)) {
      final e = Entry.fromJson(
        row.id,
        activeVault.openJson(row.id, row.ciphertext),
      );
      references.addAll(e.attachments.map((a) => a.id));
    }
    final files = <String, String>{};
    for (final id in references) {
      files[id] = base64Encode(await _encryptedAttachment(id));
      checkAccount();
    }
    Map<String, dynamic>? latest;
    try {
      latest = await activeCloud?.vault().timeout(const Duration(seconds: 8));
    } catch (_) {
      /* Cached key envelopes permit offline backups. */
    }
    checkAccount();
    if (latest != null) _cacheHeader(latest);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'quiet-campus-backup',
          'v': 1,
          'owner': activeOwner,
          'syncStatus': syncStatus,
          'vault': jsonDecode(activeStore.meta('vault')!),
          'records': snapshotRecords.map((r) => r.toJson()).toList(),
          'conflicts': {
            for (final e in snapshotConflicts.entries) e.key: e.value.toJson(),
          },
          'attachments': files,
        }),
      ),
    );
  }

  @override
  Future<bool> enableNotifications(bool enabled) async {
    if (enabled && !await reminders.requestPermission()) return false;
    notificationsEnabled = enabled;
    store!.setMeta('notifications', '$enabled');
    await reminders.reconcile(entries, enabled: enabled);
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    if (store?.pending.isNotEmpty == true || conflicts.isNotEmpty) {
      throw StateError('还有未同步或冲突的记录，请先完成同步再退出；也可以先锁定档案。');
    }
    await _close(erase: true);
    await client.auth.signOut(scope: SignOutScope.local);
    notifyListeners();
  }

  Future<void> switchAccount() async {
    // Account-specific ciphertext and outbox must survive switching, including offline edits.
    await _close();
    await client.auth.signOut(scope: SignOutScope.local);
    notifyListeners();
  }

  Future<void> deleteAccount(String code) async {
    await client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: code.trim(),
    );
    _closing = true;
    await engine?.stop();
    try {
      final result = await client.functions.invoke('delete-account');
      if (result.status != 200 || result.data?['deleted'] != true) {
        throw StateError('删除尚未完成，请重试');
      }
      await _close(erase: true);
      await client.auth.signOut(scope: SignOutScope.local);
      notifyListeners();
    } catch (_) {
      engine = SyncEngine(store!, cloud!);
      _closing = false;
      rethrow;
    }
  }

  Future<void> _close({bool erase = false}) async {
    _closing = true;
    _timer?.cancel();
    _timer = null;
    if (_channel != null) {
      try {
        await client
            .removeChannel(_channel!)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* Local cleanup must also work while offline. */
      }
      _channel = null;
    }
    await engine?.stop();
    engine = null;
    try {
      await reminders.reconcile([], enabled: false);
    } catch (_) {
      reminders.warning = '无法更新系统提醒，请在系统设置中关闭通知。';
    }
    lock();
    final id = owner;
    store?.close();
    store = null;
    if (erase && id != null) {
      await secure.delete(key: 'quiet-campus.vault.$id');
      final directory = await getApplicationSupportDirectory();
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File(p.join(directory.path, '$id.sqlite$suffix'));
        if (await file.exists()) await file.delete();
      }
    }
    header = null;
    headerRevision = 0;
    accountReady = false;
    owner = null;
    syncStatus = '尚未同步';
    notificationsEnabled = false;
    _closing = false;
  }
}
