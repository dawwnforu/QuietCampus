import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'archive_actions.dart';
import 'model.dart';

/// Deliberately separate from the encrypted native vault: no account or network.
class DemoController extends ArchiveActions {
  @override
  bool get isDemo => true;
  DemoController() {
    final now = DateTime.now();
    entries = [
      for (final sample in [
        ('note', '有点紧张，也有一点进步', '今天第一次在读书会上发言。\n下次想试试提前写下三个要点。\n', '大学生活'),
        (
          'experience',
          '社区图书馆志愿服务',
          '我负责引导读者、整理儿童阅读区。\n第一次独立完成了图书分类，很有成就感。\n',
          '志愿',
        ),
        (
          'project',
          '校园旧物循环小程序',
          '目标：让闲置的课本找到下一位读者。\n我负责需求访谈，目前已整理出第一版流程。\n',
          '课程项目',
        ),
      ])
        Entry(
          id: const Uuid().v4(),
          kind: sample.$1,
          title: sample.$2,
          delta: [
            {'insert': sample.$3},
          ],
          tags: [sample.$4],
          createdAt: now,
          updatedAt: now,
        ),
      for (var i = 1; i <= 10; i++)
        Entry(
          id: const Uuid().v4(),
          title: ['一次小小的尝试', '课堂之外的发现', '和自己聊一会儿'][i % 3],
          delta: const [
            {'insert': '慢慢把今天的收获写下来，也留一点空白给明天。\n'},
          ],
          kind: i % 4 == 0 ? 'experience' : 'note',
          tags: const ['大学生活'],
          createdAt: DateTime(now.year, now.month, now.day - i * 6),
          updatedAt: DateTime(now.year, now.month, now.day - i * 6),
        ),
      for (final event in [
        (10, '图书馆志愿服务', 0),
        (15, '小组项目讨论', 0),
        (9, '课程展示准备', 1),
      ])
        Entry(
          id: const Uuid().v4(),
          kind: 'activity',
          title: event.$2,
          delta: const [
            {'insert': '提前留一点准备时间。\n'},
          ],
          createdAt: now,
          updatedAt: now,
          status: ActivityStatus.registered,
          startsAt: DateTime(now.year, now.month, now.day + event.$3, event.$1),
          endsAt: DateTime(
            now.year,
            now.month,
            now.day + event.$3,
            event.$1 + 1,
          ),
          reminderTarget: 'system',
        ),
    ];
  }

  @override
  List<Entry> entries = [];
  final _files = <String, Uint8List>{};
  final _revisions = <String, int>{};
  final _deleted = <String>{};
  @override
  bool isDeleted(String id) => _deleted.contains(id);
  @override
  String get syncStatus => '交互演示 · 仅当前页面保存，刷新后重置';
  @override
  String get syncActionLabel => '刷新示例视图';
  @override
  String get deletionNotice => '删除只影响当前示例页面；刷新后示例重置，不会修改任何真实档案。';
  @override
  String get notificationWarning => '';
  @override
  bool get notificationsEnabled => false;
  @override
  Future<bool> enableNotifications(bool enabled) async => false;
  @override
  Map<String, SealedRecord> get conflicts => const {};
  @override
  Entry? entry(String id) => entries.where((e) => e.id == id).firstOrNull;
  @override
  int revisionOf(String id) => _revisions[id] ?? 0;
  @override
  Future<void> sync() async => notifyListeners();
  @override
  Future<void> save(Entry entry, {required int baseRevision}) async {
    if (!['profile', 'tag_catalog'].contains(entry.kind)) {
      await rememberTags(entry.tags);
    }
    if (revisionOf(entry.id) != baseRevision) {
      throw StateError('记录已有更新，请重新打开后编辑');
    }
    entries = [entry, ...entries.where((e) => e.id != entry.id)];
    _deleted.remove(entry.id);
    _revisions[entry.id] = baseRevision + 1;
    notifyListeners();
  }

  @override
  Future<void> deleteEntry(Entry entry) async {
    await rememberTags(entry.tags);
    entries = entries.where((e) => e.id != entry.id).toList();
    _deleted.add(entry.id);
    _revisions[entry.id] = revisionOf(entry.id) + 1;
    // Keep ciphertext-equivalent demo bytes until this demo session ends, like native tombstones.
    notifyListeners();
  }

  @override
  Future<Attachment> addAttachment(String name, Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('附件不能超过 20 MiB');
    }
    final id = const Uuid().v4();
    _files[id] = Uint8List.fromList(bytes);
    return Attachment(id: id, name: name, size: bytes.length);
  }

  @override
  Future<Uint8List> readAttachment(Attachment file) async {
    final bytes = _files[file.id];
    if (bytes == null) throw StateError('演示附件已不存在，请重新选择');
    return Uint8List.fromList(bytes);
  }

  @override
  Entry? conflictEntry(String id) => null;
  @override
  Future<void> resolve(String id, bool useLocal) async {}
}
