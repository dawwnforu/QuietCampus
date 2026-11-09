import 'package:flutter/material.dart';

import 'archive_actions.dart';
import 'model.dart';
import 'ui_helpers.dart';
import 'materials.dart';
import 'app_language.dart';

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class ArchiveStats {
  ArchiveStats(Iterable<Entry> entries) {
    for (final entry in entries.where((e) => e.isRecord)) {
      records++;
      characters += entry.characterCount;
      if (entry.kind == 'project') projects++;
      if (entry.kind == 'experience') experiences++;
      final day = calendarDay(entry.createdAt);
      days.update(day, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  int records = 0, characters = 0, projects = 0, experiences = 0;
  final days = <DateTime, int>{};
}

class ArchiveOverview extends StatelessWidget {
  const ArchiveOverview({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final ArchiveActions controller;
  final ValueChanged<Entry> onOpen;
  static const profileId = '00000000-0000-4000-8000-000000000001';
  static const fields = {
    'name': '姓名 / 昵称',
    'school': '学校',
    'major': '专业',
    'year': '年级',
    'city': '所在城市',
    'email': '联系邮箱',
    'intro': '关于自己',
  };

  Future<void> editProfile(BuildContext context) async {
    final current = controller.entry(profileId);
    final revision = controller.revisionOf(profileId);
    final inputs = {
      for (final field in fields.keys)
        field: TextEditingController(text: current?.profile[field] ?? ''),
    };
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(context.t('我的个人资料')),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.isDemo
                            ? context.t('演示资料仅保留在此页面，刷新后重置；请只填写示例内容。')
                            : context.t('每项都可以留空。资料仅用于自己的档案，与记录一起加密保存。'),
                      ),
                      const SizedBox(height: 18),
                      for (final field in fields.entries) ...[
                        TextField(
                          controller: inputs[field.key],
                          maxLength: field.key == 'intro' ? 500 : 100,
                          maxLines: field.key == 'intro' ? 3 : 1,
                          decoration: InputDecoration(
                            labelText: context.t(field.value),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: Text(context.t('取消')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            final now = DateTime.now();
                            await controller.save(
                              Entry(
                                id: profileId,
                                title: '我的个人资料',
                                kind: 'profile',
                                delta: const [
                                  {'insert': '\n'},
                                ],
                                profile: inputs.map(
                                  (key, value) =>
                                      MapEntry(key, value.text.trim()),
                                ),
                                createdAt: current?.createdAt ?? now,
                                updatedAt: now,
                              ),
                              baseRevision: revision,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } catch (error) {
                            if (context.mounted) showFailure(context, error);
                          } finally {
                            if (context.mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(saving ? context.t('保存中…') : context.t('保存资料')),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      // Dialog route animations can still read their text controllers until unmounted.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      for (final input in inputs.values) {
        input.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ArchiveStats(controller.entries);
    final profile =
        controller.entry(profileId)?.profile ?? const <String, String>{};
    final theme = Theme.of(context);
    final today = calendarDay(DateTime.now());
    final start = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) - 77,
    );
    final materials = controller.entries
        .where(
          (e) =>
              e.kind != 'profile' &&
              e.kind != 'material' &&
              e.attachments.isNotEmpty,
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xffedf3ef),
                child: ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: Text(context.t('材料库')),
                  subtitle: Text(
                    context.t('{count} 份原件 · 证件、奖项、经历证明与作品', {
                      'count': controller.entries
                          .where((e) => e.kind == 'material')
                          .length,
                    }),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaterialsLibrary(controller: controller),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: .55,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 27,
                          child: Icon(Icons.person_outline, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['name']?.isNotEmpty == true
                                    ? profile['name']!
                                    : context.t('我的成长档案'),
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                      profile['school'],
                                      profile['major'],
                                      profile['year'],
                                    ]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => editProfile(context),
                          tooltip: context.t('编辑个人资料'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile['intro']?.isNotEmpty == true
                          ? profile['intro']!
                          : context.t('慢慢经历，慢慢了解自己。这里的每一页，都只属于你。'),
                    ),
                    if ([
                      profile['city'],
                      profile['email'],
                    ].any((v) => v?.isNotEmpty == true)) ...[
                      const SizedBox(height: 12),
                      Text(
                        [profile['city'], profile['email']]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.t('个人资料 · 仅自己可见'),
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final metric in [
                      ('留下记录', stats.records, '次'),
                      ('写下字数', stats.characters, '字'),
                      ('存下项目', stats.projects, '个'),
                      ('记录过的日子', stats.days.length, '天'),
                    ])
                      SizedBox(
                        width:
                            (constraints.maxWidth -
                                (constraints.maxWidth >= 680 ? 36 : 12)) /
                            (constraints.maxWidth >= 680 ? 4 : 2),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t(metric.$1),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text.rich(
                                  TextSpan(
                                    text: '${metric.$2}',
                                    style: theme.textTheme.headlineMedium,
                                    children: [
                                      TextSpan(
                                        text: ' ${context.t(metric.$3)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('字数按正文非空白字符统计，含标点；修改同一条记录不会增加记录次数。'),
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 28),
              Card(
                color: Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('日子留下的痕迹'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('最近 12 周 · 点一个日期，看看那天写下了什么'),
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cell = ((constraints.maxWidth - 28) / 12 - 4)
                              .clamp(8.0, 24.0);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  for (final label
                                      in context.english
                                          ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                          : ['一', '二', '三', '四', '五', '六', '日'])
                                    SizedBox(
                                      height: cell + 4,
                                      width: 24,
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              for (var week = 0; week < 12; week++)
                                Expanded(
                                  child: Column(
                                    children: [
                                      for (var day = 0; day < 7; day++)
                                        Builder(
                                          builder: (context) {
                                            final date = DateTime(
                                              start.year,
                                              start.month,
                                              start.day + week * 7 + day,
                                            );
                                            final count = stats.days[date] ?? 0;
                                            final future = date.isAfter(today);
                                            final label = context.english
                                                ? '${MaterialLocalizations.of(context).formatFullDate(date)} · $count records'
                                                : '${date.year}年${date.month}月${date.day}日 · $count 条记录';
                                            return Tooltip(
                                              message: label,
                                              preferBelow: false,
                                              verticalOffset: 24,
                                              child: Semantics(
                                                label: label,
                                                button: !future,
                                                child: InkWell(
                                                  onTap: future
                                                      ? null
                                                      : () => showDialog<void>(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: Text(
                                                              context.english
                                                                  ? 'Notes · ${MaterialLocalizations.of(context).formatMediumDate(date)}'
                                                                  : '${date.month}月${date.day}日的记录',
                                                            ),
                                                            content: SizedBox(
                                                              width: 420,
                                                              child: SingleChildScrollView(
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    if (count ==
                                                                        0)
                                                                      Text(
                                                                        context
                                                                            .t(
                                                                              '这天没有记录。留白也是生活的一部分。',
                                                                            ),
                                                                      ),
                                                                    for (final entry in controller.entries.where(
                                                                      (e) =>
                                                                          e.isRecord &&
                                                                          calendarDay(
                                                                                e.createdAt,
                                                                              ) ==
                                                                              date,
                                                                    ))
                                                                      ListTile(
                                                                        title: Text(
                                                                          entry.title.isEmpty
                                                                              ? context.t(
                                                                                  '无题记录',
                                                                                )
                                                                              : entry.title,
                                                                        ),
                                                                        subtitle: Text(
                                                                          context.t(
                                                                            entry.kindLabel,
                                                                          ),
                                                                        ),
                                                                        onTap: () {
                                                                          Navigator.pop(
                                                                            context,
                                                                          );
                                                                          onOpen(
                                                                            entry,
                                                                          );
                                                                        },
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                                child: Text(
                                                                  context.t(
                                                                    '关闭',
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                  child: Container(
                                                    width: cell,
                                                    height: cell,
                                                    margin:
                                                        const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      color: future
                                                          ? Colors.transparent
                                                          : count == 0
                                                          ? const Color(
                                                              0xffeef0eb,
                                                            )
                                                          : theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha:
                                                                      (.25 +
                                                                              count *
                                                                                  .2)
                                                                          .clamp(
                                                                            .25,
                                                                            1,
                                                                          ),
                                                                ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t('颜色越深，当天留下的记录越多。没有连续打卡要求。'),
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('这半年的记录'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      for (var offset = 5; offset >= 0; offset--)
                        Builder(
                          builder: (context) {
                            final month = DateTime(
                              today.year,
                              today.month - offset,
                            );
                            final count = stats.days.entries
                                .where(
                                  (e) =>
                                      e.key.year == month.year &&
                                      e.key.month == month.month,
                                )
                                .fold(0, (sum, e) => sum + e.value);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      context.english
                                          ? const [
                                              'Jan',
                                              'Feb',
                                              'Mar',
                                              'Apr',
                                              'May',
                                              'Jun',
                                              'Jul',
                                              'Aug',
                                              'Sep',
                                              'Oct',
                                              'Nov',
                                              'Dec',
                                            ][month.month - 1]
                                          : '${month.month} 月',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value:
                                          count /
                                          (stats.records == 0
                                              ? 1
                                              : stats.records),
                                      minHeight: 10,
                                      borderRadius: BorderRadius.circular(5),
                                      backgroundColor: const Color(0xffeef0eb),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      context.english ? '$count' : '$count 次',
                                      textAlign: TextAlign.end,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(context.t('经历与材料'), style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                context.t('留过 {experiences} 段经历 · {files} 份附件', {
                  'experiences': stats.experiences,
                  'files': materials.fold<int>(
                    0,
                    (n, e) => n + e.attachments.length,
                  ),
                }),
              ),
              if (materials.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(context.t('以后留下的照片、作品和证明，会汇集在这里。')),
                ),
              for (final entry in materials)
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(
                      entry.title.isEmpty ? context.t('无题记录') : entry.title,
                    ),
                    subtitle: Text(
                      '${context.t('{count} 份附件', {'count': entry.attachments.length})} · ${context.t(entry.kindLabel)}',
                    ),
                    onTap: () => onOpen(entry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
