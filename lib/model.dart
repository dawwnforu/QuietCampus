import 'dart:convert';

import 'record_search.dart';

List<String> parseTagNames(String value) {
  final names = value
      .split(RegExp(r'[#＃,，\s]+'))
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
  if (names.any(
    (s) => s.runes.length > 64 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(s),
  )) {
    throw const FormatException('每个标签最多 64 个字符，不能包含控制字符');
  }
  return names;
}

enum ActivityStatus {
  interested('感兴趣'),
  registered('已报名'),
  ongoing('进行中'),
  completed('已完成'),
  cancelled('已取消');

  const ActivityStatus(this.label);
  final String label;
}

class Attachment {
  const Attachment({required this.id, required this.name, required this.size});
  final String id;
  final String name;
  final int size;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'size': size};
  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as String,
    name: json['name'] as String,
    size: json['size'] as int,
  );
}

class Entry {
  Entry({
    required this.id,
    required this.title,
    required this.delta,
    required this.createdAt,
    required this.updatedAt,
    this.kind = 'note',
    this.tags = const [],
    this.attachments = const [],
    this.activityId,
    this.status = ActivityStatus.interested,
    this.deadline,
    this.reminder,
    this.role = '',
    this.startsAt,
    this.endsAt,
    this.reminderTarget = 'app',
    this.profile = const {},
    this.materialCategory = '其他',
    this.materialDate,
  });

  final String id;
  final String title;
  final String kind;
  final List<dynamic> delta;
  final List<String> tags;
  final List<Attachment> attachments;
  final String? activityId;
  final ActivityStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deadline;
  final DateTime? reminder;
  final String role;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String reminderTarget;
  final Map<String, String> profile;
  final String materialCategory;
  final DateTime? materialDate;
  bool get isRecord => ['note', 'experience', 'project'].contains(kind);
  Set<String> get materialIds => materialReferences(delta);
  DateTime? get scheduleDate => startsAt ?? deadline ?? reminder;
  int get characterCount =>
      plainText.replaceAll(RegExp(r'\s', unicode: true), '').runes.length;

  String get kindLabel => switch (kind) {
    'profile' => '个人资料',
    'tag_catalog' => '历史标签',
    'activity' => '活动',
    'experience' => '经历',
    'project' => '项目',
    'material' => '材料',
    _ => '日记',
  };

  String get plainText => kind == 'tag_catalog'
      ? tags.join('\n')
      : kind == 'profile'
      ? profile.values.join('\n')
      : delta.map((op) {
          final insert = (op as Map)['insert'];
          return insert is String ? insert : '';
        }).join();

  EntryMatch? search(String query, {String? displayKind}) {
    final displayed = searchRecordFields(
      title: title,
      kind: displayKind ?? kindLabel,
      body: plainText,
      tags: tags,
      role: kind == 'material' ? '$materialCategory $role' : role,
      query: query,
    );
    if (displayed != null || displayKind == null || displayKind == kindLabel) {
      return displayed;
    }
    final original = search(query);
    // An alias can find a record, but its offsets do not describe the displayed label.
    return original == null
        ? null
        : EntryMatch(
            original.title,
            [],
            original.body,
            original.tags,
            original.role,
          );
  }

  bool matches(String query) => search(query) != null;

  Map<String, dynamic> toJson() => {
    'v':
        kind == 'material' ||
            delta.any((op) => op is Map && op['insert'] is! String)
        ? 2
        : 1,
    'kind': kind,
    'title': title,
    'delta': delta,
    'tags': tags,
    'attachments': attachments.map((e) => e.toJson()).toList(),
    'activityId': activityId,
    'status': status.name,
    'role': role,
    'startsAt': startsAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
    'reminderTarget': reminderTarget,
    'profile': profile,
    if (kind == 'material') 'materialCategory': materialCategory,
    if (kind == 'material')
      'materialDate': materialDate == null
          ? null
          : '${materialDate!.year}-${materialDate!.month.toString().padLeft(2, '0')}-${materialDate!.day.toString().padLeft(2, '0')}',
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deadline': deadline?.toUtc().toIso8601String(),
    'reminder': reminder?.toUtc().toIso8601String(),
  };

  factory Entry.fromJson(String id, Map<String, dynamic> json) {
    if (!['app', 'system'].contains(json['reminderTarget'] ?? 'app')) {
      throw const FormatException('不支持的提醒方式');
    }
    if (![1, 2].contains(json['v']) ||
        ![
          'note',
          'activity',
          'experience',
          'project',
          'profile',
          'tag_catalog',
          'material',
        ].contains(json['kind'])) {
      throw const FormatException('此档案需要更新静档客户端；原始密文仍保留，请勿用旧版本修改');
    }
    return Entry(
      id: id,
      title: json['title'] as String,
      kind: json['kind'] as String,
      delta: json['delta'] as List,
      tags: (json['tags'] as List).cast<String>(),
      attachments: (json['attachments'] as List)
          .map((a) => Attachment.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      activityId: json['activityId'] as String?,
      status: ActivityStatus.values.byName(json['status'] as String),
      role: json['role'] as String,
      startsAt: DateTime.tryParse(json['startsAt'] as String? ?? '')?.toLocal(),
      endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '')?.toLocal(),
      reminderTarget: json['reminderTarget'] as String? ?? 'app',
      profile: (json['profile'] as Map? ?? const {}).cast<String, String>(),
      materialCategory: json['materialCategory'] as String? ?? '其他',
      materialDate: DateTime.tryParse(json['materialDate'] as String? ?? ''),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '')?.toLocal(),
      reminder: DateTime.tryParse(json['reminder'] as String? ?? '')?.toLocal(),
    );
  }
}

const materialEmbedType = 'quiet-material-v1';

String? materialReference(dynamic insert) {
  if (insert is! Map || insert['custom'] is! String) return null;
  try {
    final value = jsonDecode(insert['custom'] as String);
    final id = value is Map ? value[materialEmbedType] : null;
    return id is String && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)
        ? id
        : null;
  } on FormatException {
    return null;
  }
}

Set<String> materialReferences(List<dynamic> delta) => {
  for (final op in delta)
    if (op is Map)
      if (materialReference(op['insert']) case final String id) id,
};

List<dynamic> withMaterialReference(List<dynamic> delta, String id) => [
  ...delta,
  {
    'insert': {
      'custom': jsonEncode({materialEmbedType: id}),
    },
  },
  {'insert': '\n'},
];

class SealedRecord {
  const SealedRecord({
    required this.id,
    required this.revision,
    required this.ciphertext,
    required this.deleted,
    this.dirty = false,
    this.generation = 0,
    this.mutationId = '',
  });
  final String id;
  final int revision;
  final Map<String, dynamic> ciphertext;
  final bool deleted;
  final bool dirty;
  final int generation;
  final String mutationId;
  factory SealedRecord.fromRemote(Map<String, dynamic> json) => SealedRecord(
    id: json['id'] as String,
    revision: json['revision'] as int,
    ciphertext: Map<String, dynamic>.from(json['ciphertext'] as Map),
    deleted: json['deleted'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    'ciphertext': ciphertext,
    'deleted': deleted,
    'dirty': dirty,
    'generation': generation,
    'mutationId': mutationId,
  };
  String encode() => jsonEncode(toJson());
}
