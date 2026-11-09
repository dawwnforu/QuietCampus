import 'dart:convert';
import 'dart:typed_data';

const maxArchiveBytes = 64 * 1024 * 1024;

class StoredSnapshot {
  StoredSnapshot(this.revision, this.bytes);
  final int revision;
  final Uint8List bytes;
  String encode() => '$revision\n${utf8.decode(bytes)}';

  factory StoredSnapshot.decode(String value) {
    final split = value.indexOf('\n');
    final revision = split < 1 ? null : int.tryParse(value.substring(0, split));
    if (revision == null || revision < 1) {
      throw const FormatException('本地存储版本损坏，请保留资料并从备份恢复');
    }
    return StoredSnapshot(
      revision,
      Uint8List.fromList(utf8.encode(value.substring(split + 1))),
    );
  }
}

abstract interface class SnapshotStore {
  Future<StoredSnapshot?> read();
  Future<int> commit(Uint8List bytes, {required int baseRevision});
}
