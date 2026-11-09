import 'package:flutter/foundation.dart';

import 'model.dart';

/// Operations shared by the native vault and the isolated, in-memory UI demo.
abstract class ArchiveActions extends ChangeNotifier {
  static const tagCatalogId = '00000000-0000-4000-8000-000000000002';
  bool get isDemo => false;
  bool get unlocked => true;
  bool isDeleted(String id) => false;
  List<Entry> get entries;
  String get syncStatus;
  String get syncActionLabel => '同步';
  String get deletionNotice => '删除会同步到其他设备。发生版本冲突时，会保留未同步的修改供你选择。';
  String get notificationWarning;
  bool get notificationsEnabled;
  Future<bool> enableNotifications(bool enabled);
  Map<String, SealedRecord> get conflicts;
  int revisionOf(String id);
  Entry? entry(String id);
  Future<void> sync();
  Future<void> save(Entry entry, {required int baseRevision});
  Future<void> deleteEntry(Entry entry);
  Future<Attachment> addAttachment(String name, Uint8List bytes);
  Future<Uint8List> readAttachment(Attachment file);
  Entry? conflictEntry(String id);
  Future<void> resolve(String id, bool useLocal);

  List<String> get knownTags =>
      entries
          .where((e) => e.kind != 'profile')
          .expand((e) => e.tags)
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  Future<void> rememberTags(Iterable<String> tags) async {
    final names = {
      ...knownTags,
      ...tags,
    }.where((name) => name.isNotEmpty).toList()..sort();
    if (names.isEmpty || listEquals(entry(tagCatalogId)?.tags, names)) return;
    await _saveTagCatalog(names);
  }

  Future<void> _saveTagCatalog(List<String> names) async {
    final now = DateTime.now();
    final current = entry(tagCatalogId);
    await save(
      Entry(
        id: tagCatalogId,
        kind: 'tag_catalog',
        title: '历史标签',
        delta: const [
          {'insert': '\n'},
        ],
        tags: names,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      ),
      baseRevision: revisionOf(tagCatalogId),
    );
  }

  Future<int> renameTag(String oldName, String newName) async {
    final names = parseTagNames(newName);
    if (names.length != 1) throw const FormatException('请输入一个标签名称');
    if (names.single == oldName) return 0;
    return _changeTag(oldName, names.single);
  }

  Future<int> deleteTag(String name) => _changeTag(name, null);

  Future<int> _changeTag(String oldName, String? newName) async {
    if (!knownTags.contains(oldName)) throw StateError('这个标签已变更，请重新选择');
    final ids = entries
        .where(
          (e) =>
              e.kind != 'tag_catalog' &&
              e.kind != 'profile' &&
              e.tags.contains(oldName),
        )
        .map((e) => e.id)
        .toList();
    var changed = 0;
    try {
      for (final id in ids) {
        // Re-read before each write so unrelated, newer fields remain intact.
        final current = entry(id);
        if (current == null || !current.tags.contains(oldName)) continue;
        final revision = revisionOf(id);
        final tags = current.tags
            .map((tag) => tag == oldName ? newName : tag)
            .whereType<String>()
            .toSet()
            .toList();
        await save(
          Entry.fromJson(id, {
            ...current.toJson(),
            'tags': tags,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }),
          baseRevision: revision,
        );
        changed++;
      }
      final names = knownTags.toSet()..remove(oldName);
      if (newName != null) names.add(newName);
      await _saveTagCatalog(names.toList()..sort());
      return changed;
    } catch (_) {
      throw StateError('标签更新尚未完成，已处理 $changed 条记录。可以重试；记录正文和附件仍然保留。');
    }
  }
}
