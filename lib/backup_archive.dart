import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:sodium/sodium_sumo.dart';

import 'model.dart';
import 'snapshot_store.dart';
import 'vault_crypto.dart';

/// Validates an imported snapshot without touching a database or cloud account.
class BackupArchive {
  BackupArchive._(
    this.owner,
    this.vaultRow,
    this.records,
    this.conflicts,
    this.files,
  );

  // Bound JSON/base64 expansion before parsing on mobile browsers.
  static const maxBytes = maxArchiveBytes;
  static const maxAttachmentBytes = 20 * 1024 * 1024;
  static final _fileId = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final String owner;
  final Map<String, dynamic> vaultRow;
  final List<SealedRecord> records;
  final Map<String, SealedRecord> conflicts;
  final Map<String, Uint8List> files;

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('备份结构不完整');
    return value;
  }

  static String _id(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        RegExp(r'[\x00-\x20\x7f/\\]').hasMatch(value)) {
      throw const FormatException('备份包含无效对象标识');
    }
    return value;
  }

  static Uint8List _base64(Object? value, int maximum) {
    if (value is! String || value.length > ((maximum + 2) ~/ 3) * 4) {
      throw const FormatException('备份密文大小无效');
    }
    final result = base64Decode(value);
    if (result.length > maximum) throw const FormatException('备份密文过大');
    return result;
  }

  static Map<String, dynamic> _box(Object? value, {int? plainBytes}) {
    final box = _object(value);
    if (box['v'] != 1 ||
        box.keys.toSet().difference({'v', 'nonce', 'box'}).isNotEmpty ||
        _base64(box['nonce'], 24).length != 24) {
      throw const FormatException('不支持或损坏的密文封装');
    }
    final data = _base64(box['box'], 2 * 1024 * 1024);
    if (data.length < 16 ||
        (plainBytes != null && data.length != plainBytes + 16)) {
      throw const FormatException('密文长度无效');
    }
    return box;
  }

  factory BackupArchive.decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('请选择不超过 64 MiB 的完整加密备份；原资料未改动');
    }
    try {
      final root = _object(jsonDecode(utf8.decode(bytes)));
      if (root['format'] != 'quiet-campus-backup' || root['v'] != 1) {
        throw const FormatException('备份格式或版本不受支持，请保留原文件');
      }
      final owner = _id(root['owner']);
      final vault = _object(root['vault']);
      if (vault['owner_id'] != null && vault['owner_id'] != owner) {
        throw const FormatException('备份账号标识不一致');
      }
      if (vault['revision'] is! int || (vault['revision'] as int) < 1) {
        throw const FormatException('密钥版本无效');
      }
      final header = _object(vault['envelope']);
      if (header['v'] != 1 ||
          header['ops'] != VaultCrypto.ops ||
          header['mem'] != VaultCrypto.memory ||
          _base64(header['salt'], 16).length != 16) {
        throw const FormatException('不支持或损坏的密钥格式');
      }
      _box(header['pass'], plainBytes: 32);
      _box(header['recovery'], plainBytes: 32);
      if (root['records'] is! List) throw const FormatException('缺少记录清单');
      final ids = <String>{};
      SealedRecord record(Object? value) {
        final row = _object(value);
        final id = _id(row['id']);
        if (row['revision'] is! int ||
            (row['revision'] as int) < 0 ||
            row['deleted'] is! bool) {
          throw const FormatException('记录版本无效');
        }
        if (row['dirty'] != null && row['dirty'] is! bool) {
          throw const FormatException('待同步标记无效');
        }
        if (row['generation'] != null &&
            (row['generation'] is! int || (row['generation'] as int) < 0)) {
          throw const FormatException('本机记录版本无效');
        }
        _box(row['ciphertext']);
        return SealedRecord(
          id: id,
          revision: row['revision'] as int,
          ciphertext: _object(row['ciphertext']),
          deleted: row['deleted'] as bool,
          dirty: row['dirty'] as bool? ?? false,
          generation: row['generation'] as int? ?? 0,
          mutationId: row['mutationId'] as String? ?? '',
        );
      }

      final records = [
        for (final value in root['records'] as List) record(value),
      ];
      for (final row in records) {
        if (!ids.add(row.id)) throw const FormatException('备份记录标识重复，未导入');
      }
      final conflicts = <String, SealedRecord>{};
      for (final pair in _object(root['conflicts']).entries) {
        final row = record(pair.value);
        if (pair.key != row.id || !ids.contains(row.id)) {
          throw const FormatException('冲突版本没有对应的本机记录');
        }
        conflicts[pair.key] = row;
      }
      final files = <String, Uint8List>{};
      for (final pair in _object(root['attachments']).entries) {
        if (!_fileId.hasMatch(pair.key)) throw const FormatException('附件标识无效');
        final frame = _base64(pair.value, maxAttachmentBytes + 41);
        if (frame.length < 41 || frame[0] != 1) {
          throw const FormatException('附件封装损坏或不受支持');
        }
        files[pair.key] = frame;
      }
      return BackupArchive._(owner, vault, records, conflicts, files);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份损坏或结构不受支持，原资料未改动');
    }
  }

  /// Authenticates every record and file before a caller can offer a restore.
  Future<OpenedBackup> unlock(
    SodiumSumo sodium,
    String secret, {
    bool recovery = false,
  }) async {
    final vault = await VaultCrypto.unlock(
      sodium,
      owner,
      _object(vaultRow['envelope']),
      secret,
      recovery: recovery,
    );
    try {
      final lengths = <String, int>{};
      for (final file in files.entries) {
        final bytes = vault.openAttachment(file.key, file.value);
        try {
          lengths[file.key] = bytes.length;
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      }
      Entry? open(SealedRecord row) {
        final json = vault.openJson(row.id, row.ciphertext);
        if (row.deleted) {
          if (json['deleted'] != true) {
            throw const FormatException('删除标记与记录内容不一致');
          }
          return null;
        }
        final entry = Entry.fromJson(row.id, json);
        Document.fromJson(entry.delta);
        for (final op in entry.delta) {
          if (op is! Map ||
              (op['insert'] is! String &&
                  materialReference(op['insert']) == null)) {
            throw const FormatException('备份包含当前版本不能显示的富文本块');
          }
        }
        for (final file in entry.attachments) {
          if (!lengths.containsKey(file.id) ||
              lengths[file.id] != file.size ||
              file.size < 0 ||
              file.size > maxAttachmentBytes) {
            throw const FormatException('备份缺少附件或附件大小不一致');
          }
        }
        return entry;
      }

      final entries = [
        for (final row in records)
          if (open(row) case final Entry entry) entry,
      ];
      final conflictEntries = {
        for (final pair in conflicts.entries) pair.key: open(pair.value),
      };
      return OpenedBackup(this, vault, entries, conflictEntries);
    } catch (_) {
      vault.dispose();
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'format': 'quiet-campus-backup',
    'v': 1,
    'owner': owner,
    'vault': vaultRow,
    'records': records.map((r) => r.toJson()).toList(),
    'conflicts': {
      for (final pair in conflicts.entries) pair.key: pair.value.toJson(),
    },
    'attachments': {
      for (final pair in files.entries) pair.key: base64Encode(pair.value),
    },
  };
}

class OpenedBackup {
  OpenedBackup(this.archive, this.vault, this.entries, this.conflicts);
  final BackupArchive archive;
  final VaultCrypto vault;
  final List<Entry> entries;
  final Map<String, Entry?> conflicts;
  void dispose() => vault.dispose();
}
