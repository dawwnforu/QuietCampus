import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart' show EntryDetail, ConflictsPage;
import 'archive_actions.dart';
import 'editor.dart';
import 'model.dart';
import 'notes_browser.dart';
import 'overview.dart';
import 'planner.dart';
import 'materials.dart';
import 'app_language.dart';

class ArchiveHome extends StatefulWidget {
  const ArchiveHome({
    super.key,
    required this.controller,
    this.settingsBuilder,
    this.accountBuilder,
  });
  final ArchiveActions controller;
  final WidgetBuilder? settingsBuilder;
  final WidgetBuilder? accountBuilder;
  @override
  State<ArchiveHome> createState() => _ArchiveHomeState();
}

class _ArchiveHomeState extends State<ArchiveHome> with WidgetsBindingObserver {
  int section = 0;
  bool navigationVisible = true;
  GlobalKey notesKey = GlobalKey();
  String? selected;
  String query = '';
  Entry? editingEntry;
  final inlineEditorKey = GlobalKey<EntryEditorState>();
  DateTime today = DateTime.now();
  Timer? dayTimer;
  ArchiveActions get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshDate();
  }

  void refreshDate() {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(today, now)) setState(() => today = now);
    dayTimer?.cancel();
    dayTimer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      refreshDate,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDate();
  }

  @override
  void dispose() {
    dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> finishEditing() async {
    if (editingEntry == null) return true;
    if (!await (inlineEditorKey.currentState?.confirmDiscard() ??
            Future.value(true)) ||
        !mounted) {
      return false;
    }
    setState(() => editingEntry = null);
    return true;
  }

  Future<void> changeSection(int value) async {
    if (section == value || !await finishEditing() || !mounted) return;
    setState(() {
      section = value;
      selected = null;
      query = '';
    });
  }

  Future<void> edit([Entry? entry, String kind = 'note']) async {
    if (entry != null &&
        entry.isRecord &&
        section == 0 &&
        MediaQuery.sizeOf(context).width >= 1000) {
      if (!await finishEditing() || !mounted) return;
      setState(() {
        selected = entry.id;
        editingEntry = entry;
      });
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => entry?.kind == 'material'
            ? MaterialEditor(controller: c, entry: entry)
            : EntryEditor(controller: c, entry: entry, kind: kind),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> newRecord() async {
    if (!await finishEditing() || !mounted) return;
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t('新记录')),
        children: [
          for (final option in [
            ('note', Icons.book_outlined, '写日记', '留下今天的想法与心情'),
            ('experience', Icons.auto_awesome_outlined, '留经历', '记下参与、承担与收获'),
            ('project', Icons.folder_outlined, '存项目', '整理目标、过程与成果'),
          ])
            ListTile(
              leading: Icon(option.$2),
              title: Text(context.t(option.$3)),
              subtitle: Text(context.t(option.$4)),
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ],
      ),
    );
    if (kind != null && mounted) {
      setState(() {
        section = 0;
        selected = null;
        query = '';
        notesKey = GlobalKey();
      });
      await edit(null, kind);
    }
  }

  Future<void> open(Entry entry, [String searchQuery = '']) async {
    if (editingEntry?.id == entry.id) return;
    if (!await finishEditing() || !mounted) return;
    if (entry.kind == 'material') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialDetail(controller: c, id: entry.id),
        ),
      );
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 1000 && section == 0) {
      setState(() {
        selected = entry.id;
        query = searchQuery;
      });
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.t('我的记录'))),
          body: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final current = c.entry(entry.id);
              return current == null
                  ? Center(child: Text(context.t('这条记录已被删除')))
                  : EntryDetail(
                      entry: current,
                      controller: c,
                      query: searchQuery,
                      onEdit: () => edit(current),
                    );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final titles = [context.t('随笔'), context.t('活动'), context.t('档案')];
    const icons = [
      Icons.edit_note_outlined,
      Icons.calendar_month_outlined,
      Icons.person_outline,
    ];
    final current = selected == null ? null : c.entry(selected!);
    final editing = editingEntry == null
        ? null
        : EntryEditor(
            key: inlineEditorKey,
            controller: c,
            entry: editingEntry,
            onFinished: (saved) => setState(() {
              selected = saved?.id ?? selected;
              editingEntry = null;
            }),
          );
    final notes = NotesBrowser(
      key: notesKey,
      controller: c,
      onOpen: open,
      onQueryChanged: (value) => setState(() => query = value),
    );
    final Widget body = section == 2
        ? ArchiveOverview(controller: c, onOpen: open)
        : section == 1
        ? SchedulePlanner(controller: c, onOpen: open)
        : wide
        ? Row(
            children: [
              SizedBox(width: 420, child: notes),
              const VerticalDivider(width: 1),
              Expanded(
                child:
                    editing ??
                    (current == null
                        ? Center(child: Text(context.t('选一条记录，慢慢看看。')))
                        : EntryDetail(
                            entry: current,
                            controller: c,
                            query: query,
                            onEdit: () => edit(current),
                          )),
              ),
            ],
          )
        : editing ?? notes;
    final weekday = context.english
        ? const [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ][today.weekday - 1]
        : '星期${const ['一', '二', '三', '四', '五', '六', '日'][today.weekday - 1]}';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ArchiveLanguageBar(isDemo: c.isDemo),
            Expanded(
              child: Row(
                children: [
                  if (wide && navigationVisible) ...[
                    NavigationRail(
                      extended: true,
                      selectedIndex: section,
                      onDestinationSelected: changeSection,
                      leading: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          context.t('静档'),
                          style: TextStyle(
                            fontFamily: 'QuietDisplay',
                            fontSize: 28,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      destinations: [
                        for (var i = 0; i < 3; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            label: Text(titles[i]),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                          child: Row(
                            children: [
                              if (wide) ...[
                                IconButton(
                                  tooltip: navigationVisible
                                      ? context.t('收起导航')
                                      : context.t('展开导航'),
                                  icon: Icon(
                                    navigationVisible
                                        ? Icons.menu_open
                                        : Icons.menu,
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        navigationVisible = !navigationVisible,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titles[section],
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    ),
                                    Text(
                                      context.syncStatusText(c.syncStatus),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                label:
                                    '${MaterialLocalizations.of(context).formatFullDate(today)} $weekday',
                                excludeSemantics: true,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 100,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffe7f0eb),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${today.year} / ${today.month.toString().padLeft(2, '0')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        today.day.toString().padLeft(2, '0'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      Text(
                                        weekday,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: c.sync,
                                tooltip: context.t(c.syncActionLabel),
                                icon: const Icon(Icons.sync),
                              ),
                              if (section == 2)
                                IconButton(
                                  onPressed: widget.settingsBuilder == null
                                      ? null
                                      : () => Navigator.push<void>(
                                          context,
                                          MaterialPageRoute(
                                            builder: widget.settingsBuilder!,
                                          ),
                                        ),
                                  tooltip: context.t('设置'),
                                  icon: const Icon(Icons.tune),
                                ),
                            ],
                          ),
                        ),
                        if (section == 2 && widget.accountBuilder != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Builder(builder: widget.accountBuilder!),
                          ),
                        if (c.conflicts.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.copy_all_outlined),
                            title: Text(
                              context.t('{count} 条记录有两个版本', {
                                'count': c.conflicts.length,
                              }),
                            ),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConflictsPage(controller: c),
                              ),
                            ),
                          ),
                        if (c.notificationWarning.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(context.t(c.notificationWarning)),
                          ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section,
              onDestinationSelected: changeSection,
              destinations: [
                for (var i = 0; i < 3; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: titles[i]),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: editingEntry != null
          ? null
          : SizedBox(
              width: 64,
              height: 64,
              child: FloatingActionButton(
                onPressed: newRecord,
                tooltip: context.t('新记录'),
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 34),
              ),
            ),
    );
  }
}
