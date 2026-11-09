import 'package:flutter/material.dart';

import 'archive_actions.dart';
import 'editor.dart';
import 'model.dart';
import 'record_export.dart';
import 'record_search.dart';
import 'search_highlight.dart';
import 'tags.dart';
import 'ui_helpers.dart';
import 'rabbit_story.dart';
import 'rabbit_avatar.dart';
import 'app_language.dart';

class NotesBrowser extends StatefulWidget {
  const NotesBrowser({
    super.key,
    required this.controller,
    required this.onOpen,
    this.onQueryChanged,
    this.tagScope,
  });
  final ArchiveActions controller;
  final void Function(Entry entry, String query) onOpen;
  final ValueChanged<String>? onQueryChanged;
  final String? tagScope;
  @override
  State<NotesBrowser> createState() => _NotesBrowserState();
}

class _NotesBrowserState extends State<NotesBrowser> {
  final search = TextEditingController();
  final scroll = ScrollController();
  String kind = 'all';
  String? tag;
  int shown = 20;
  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  void changeQuery(String value) {
    setState(() => shown = 20);
    if (scroll.hasClients) scroll.jumpTo(0);
    widget.onQueryChanged?.call(value);
  }

  Future<void> createTag() async {
    final input = TextEditingController();
    String? error;
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(context.t('新建标签')),
            content: TextField(
              controller: input,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.t('标签名称'),
                prefixText: '#',
                errorText: error == null ? null : context.t(error!),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('取消')),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final names = parseTagNames(input.text);
                    if (names.length != 1) {
                      throw const FormatException('请输入一个标签名称');
                    }
                    Navigator.pop(context, names.single);
                  } on FormatException catch (failure) {
                    update(() => error = failure.message);
                  }
                },
                child: Text(context.t('创建标签')),
              ),
            ],
          ),
        ),
      );
      if (name != null) await widget.controller.rememberTags([name]);
    } catch (failure) {
      if (mounted) showFailure(context, failure);
    } finally {
      // The route still owns its input during the closing transition.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final query = search.text;
      final all =
          c.entries
              .where(
                (e) => widget.tagScope == null
                    ? e.isRecord ||
                          (query.trim().isNotEmpty || kind == 'material') &&
                              e.kind == 'material'
                    : !['profile', 'tag_catalog'].contains(e.kind) &&
                          e.tags.contains(widget.tagScope),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final rows = <({Entry entry, EntryMatch hit})>[];
      for (final entry in all) {
        if (kind != 'all' && kind != entry.kind ||
            tag != null && !entry.tags.contains(tag)) {
          continue;
        }
        final hit = entry.search(
          query,
          displayKind: context.t(entry.kindLabel),
        );
        if (hit != null) rows.add((entry: entry, hit: hit));
      }
      final visible = shown.clamp(0, rows.length);
      final theme = Theme.of(context);
      return CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.tagScope == null) ...[
                    Text(context.t('想法有地方安放，经历有迹可循。')),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: search,
                    onChanged: changeQuery,
                    decoration: InputDecoration(
                      hintText: context.t('搜索标题、正文、标签、类型 · 支持模糊词'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.t('清除搜索'),
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                search.clear();
                                changeQuery('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final option in [
                          ('all', '全部'),
                          ('note', '日记'),
                          ('experience', '经历'),
                          ('project', '项目'),
                          ('material', '材料'),
                          if (widget.tagScope != null) ('activity', '活动'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(context.t(option.$2)),
                              selected: kind == option.$1,
                              onSelected: (_) => setState(() {
                                kind = option.$1;
                                shown = 20;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.tagScope == null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: createTag,
                          icon: const Icon(Icons.tag),
                          label: Text(context.t('新建标签')),
                        ),
                        Tooltip(
                          message: context.t('管理标签'),
                          child: TextButton.icon(
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(context.t('管理标签')),
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TagManager(
                                  controller: c,
                                  onTagChanged: (oldName, newName) {
                                    if (mounted && tag == oldName) {
                                      setState(() {
                                        tag = newName;
                                        shown = 20;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => exportNotes(context, c.entries),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(context.t('导出全部随笔')),
                        ),
                      ],
                    ),
                  if (widget.tagScope == null && c.knownTags.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final name in c.knownTags)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text('#$name'),
                                selected: tag == name,
                                onSelected: (_) => setState(() {
                                  tag = tag == name ? null : name;
                                  shown = 20;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      rows.any((row) => row.entry.kind == 'material')
                          ? '{count} 条结果 · 已显示 {shown} 条'
                          : '{count} 篇记录 · 已显示 {shown} 篇',
                      {'count': rows.length, 'shown': visible},
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(context.t('没有找到匹配的记录。可以清除筛选，或留下第一笔。'))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 92),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: visible + (visible < rows.length ? 1 : 0),
                  (context, index) {
                    if (index == visible) {
                      return TextButton(
                        onPressed: () => setState(() => shown += 20),
                        child: Text(context.t('再显示 20 篇')),
                      );
                    }
                    final entry = rows[index].entry, hit = rows[index].hit;
                    final excerpt = searchExcerpt(entry.plainText, hit.body);
                    final story = entry.isRecord
                        ? rabbitStory(
                            entry,
                            english: context.english,
                            name:
                                c.entries
                                    .where((e) => e.kind == 'profile')
                                    .firstOrNull
                                    ?.profile['name'] ??
                                '',
                          )
                        : null;
                    final tags = [
                      for (var i = 0; i < entry.tags.length; i++)
                        if (i < 3 || hit.tags[i].isNotEmpty) i,
                    ];
                    return Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => widget.onOpen(entry, query),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xffeef0ec)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 3,
                                  right: 10,
                                ),
                                child: story != null
                                    ? RabbitAvatar(mood: story.mood, size: 58)
                                    : CircleAvatar(
                                        radius: 15,
                                        backgroundColor: const Color(
                                          0xffeaf5f0,
                                        ),
                                        child: Icon(
                                          switch (entry.kind) {
                                            'project' => Icons.folder_outlined,
                                            'experience' =>
                                              Icons.auto_awesome_outlined,
                                            'activity' =>
                                              Icons.calendar_month_outlined,
                                            _ => Icons.edit_note_outlined,
                                          },
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        Text(
                                          dateLabel(entry.createdAt),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        HighlightedText(
                                          context.t(entry.kindLabel),
                                          hit.kind,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        Text(
                                          context.t('{count} 字符', {
                                            'count': entry.characterCount,
                                          }),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    HighlightedText(
                                      entry.title.isEmpty
                                          ? context.t('无题记录')
                                          : entry.title,
                                      hit.title,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: query.trim().isEmpty ? 1 : 2,
                                    ),
                                    if (story != null) ...[
                                      const SizedBox(height: 5),
                                      Tooltip(
                                        message: context.t(
                                          '阿跃正在试讲：用本机文字规则整理，并非 AI 理解。内容不上传；搜索与导出仍使用原文。',
                                        ),
                                        preferBelow: false,
                                        child: Text(
                                          context.t('阿跃 · 小兔试讲'),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: const Color(0xff648277),
                                              ),
                                        ),
                                      ),
                                      HighlightedText(
                                        story.text,
                                        matchRanges(story.text, query) ?? [],
                                        style: theme.textTheme.bodyMedium,
                                        maxLines: 4,
                                      ),
                                      Text(
                                        story.gesture,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xff718478),
                                            ),
                                      ),
                                    ] else if (excerpt.text.trim().isNotEmpty)
                                      HighlightedText(
                                        excerpt.text,
                                        excerpt.ranges,
                                        style: theme.textTheme.bodyMedium,
                                        maxLines: hit.body.isEmpty ? 1 : 3,
                                      ),
                                    if (story == null && hit.role.isNotEmpty)
                                      HighlightedText(
                                        entry.role,
                                        hit.role,
                                        maxLines: 2,
                                      ),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        for (final i in tags)
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xff314d72,
                                              ),
                                              textStyle: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              minimumSize: const Size(48, 36),
                                              tapTargetSize:
                                                  MaterialTapTargetSize.padded,
                                            ),
                                            child: HighlightedText(
                                              '#${entry.tags[i]}',
                                              [
                                                for (final r in hit.tags[i])
                                                  (
                                                    start: r.start + 1,
                                                    end: r.end + 1,
                                                  ),
                                              ],
                                            ),
                                            onPressed: () => setState(() {
                                              tag = entry.tags[i];
                                              shown = 20;
                                            }),
                                          ),
                                        if (tags.length < entry.tags.length)
                                          TextButton(
                                            onPressed: () =>
                                                widget.onOpen(entry, query),
                                            child: Text(
                                              '+${entry.tags.length - tags.length}',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: context.t('打开原文：{title}', {
                                  'title': entry.title,
                                }),
                                onPressed: () => widget.onOpen(entry, query),
                                icon: const Icon(Icons.north_east, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      );
    },
  );
}
