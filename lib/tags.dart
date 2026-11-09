import 'package:flutter/material.dart';

import 'archive_actions.dart';
import 'app.dart' show EntryDetail;
import 'editor.dart';
import 'notes_browser.dart';
import 'materials.dart';
import 'model.dart';
import 'ui_helpers.dart';
import 'app_language.dart';

class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.input,
    required this.selected,
    required this.history,
    required this.onChanged,
    required this.onManage,
  });
  final TextEditingController input;
  final List<String> selected, history;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onManage;
  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final focus = FocusNode();
  String? error;
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void add([bool keepHash = false]) {
    try {
      final names = parseTagNames(widget.input.text);
      if (names.isEmpty) {
        focus.requestFocus();
        return;
      }
      widget.onChanged({...widget.selected, ...names}.toList());
      widget.input.text = keepHash ? '#' : '';
      widget.input.selection = TextSelection.collapsed(
        offset: widget.input.text.length,
      );
      setState(() => error = null);
      focus.requestFocus();
    } on FormatException catch (failure) {
      setState(() => error = failure.message);
    }
  }

  void selectHistory(String name) =>
      widget.onChanged({...widget.selected, name}.toList());

  Future<void> chooseHistory() async {
    var query = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matches = widget.history
              .where((name) => name.toLowerCase().contains(query))
              .toList();
          return AlertDialog(
            title: Text(context.t('选择历史标签')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: context.t('搜索历史标签'),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => update(() {
                      query = value
                          .replaceFirst(RegExp(r'^[#＃]'), '')
                          .trim()
                          .toLowerCase();
                    }),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SizedBox(
                      height: 280,
                      child: matches.isEmpty
                          ? Center(
                              child: Text(
                                widget.history.isEmpty
                                    ? context.t('还没有历史标签，输入 # 创建一个。')
                                    : context.t('没有匹配的历史标签'),
                              ),
                            )
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final name = matches[index];
                                final selected = widget.selected.contains(name);
                                return ListTile(
                                  title: Text('#$name'),
                                  trailing: selected
                                      ? const Icon(Icons.check)
                                      : null,
                                  enabled: !selected,
                                  onTap: () => Navigator.pop(context, name),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('取消')),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && name != null) selectHistory(name);
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.history
        .where((name) => !widget.selected.contains(name))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.t('标签'))),
            TextButton.icon(
              onPressed: widget.onManage,
              icon: const Icon(Icons.tune, size: 17),
              label: Text(context.t('管理标签')),
            ),
          ],
        ),
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in widget.selected)
                  InputChip(
                    onPressed: focus.requestFocus,
                    deleteButtonTooltipMessage: context.t('移除 #{name}', {
                      'name': name,
                    }),
                    label: Text(
                      '#$name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => widget.onChanged(
                      widget.selected.where((tag) => tag != name).toList(),
                    ),
                  ),
              ],
            ),
          ),
        TextField(
          controller: widget.input,
          focusNode: focus,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: context.t('输入 # 创建新标签，回车或空格确认'),
            errorText: error == null ? null : context.t(error!),
            prefixIcon: IconButton(
              tooltip: context.t('输入井号添加标签'),
              icon: const Text('#', style: TextStyle(fontSize: 22)),
              onPressed: () {
                if (widget.input.text.isEmpty) {
                  widget.input.text = '#';
                  widget.input.selection = const TextSelection.collapsed(
                    offset: 1,
                  );
                }
                focus.requestFocus();
                setState(() {});
              },
            ),
            suffixIcon: IconButton(
              tooltip: context.t('选择历史标签'),
              icon: const Icon(Icons.add),
              onPressed: chooseHistory,
            ),
          ),
          onSubmitted: (_) => add(),
          onChanged: (value) {
            setState(() => error = null);
            // Keep Chinese IME composition intact until the user commits the text.
            if (widget.input.value.composing.isValid &&
                !widget.input.value.composing.isCollapsed) {
              return;
            }
            if (value.trim() != '#' &&
                value.trim() != '＃' &&
                RegExp(r'[#＃,，\s]$').hasMatch(value)) {
              add(value.endsWith('#') || value.endsWith('＃'));
            }
          },
        ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in available)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: const Color(0xffeeefec),
                      side: const BorderSide(color: Color(0xffdaddd7)),
                      labelStyle: const TextStyle(color: Color(0xff686e6a)),
                      label: Text('#$name'),
                      onPressed: () => selectHistory(name),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class TagManager extends StatefulWidget {
  const TagManager({super.key, required this.controller, this.onTagChanged});
  final ArchiveActions controller;
  final void Function(String oldName, String? newName)? onTagChanged;
  @override
  State<TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends State<TagManager> {
  final search = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  int uses(String name) => widget.controller.entries
      .where(
        (e) =>
            !['profile', 'tag_catalog'].contains(e.kind) &&
            e.tags.contains(name),
      )
      .length;

  Future<void> rename(String name) async {
    final input = TextEditingController(text: name);
    String? error;
    String? target;
    try {
      target = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.t('重命名标签')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('会更新 {count} 条关联记录；名称已存在时合并标签，保留所有正文和附件。', {
                      'count': uses(name),
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: input,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.t('标签名称'),
                      prefixText: '#',
                      errorText: error == null ? null : context.t(error!),
                    ),
                  ),
                ],
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
                    setState(() => error = failure.message);
                  }
                },
                child: Text(context.t('保存名称')),
              ),
            ],
          ),
        ),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      input.dispose();
    }
    if (target == null || target == name || !mounted) return;
    final newName = target;
    await change(
      name,
      newName,
      () => widget.controller.renameTag(name, newName),
    );
  }

  Future<void> remove(String name) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('移除标签 #{name}？', {'name': name})),
        content: Text(
          context.t('会从 {count} 条记录和历史标签中移除这个标签。记录正文、项目、日程和附件都保留。', {
            'count': uses(name),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('保留')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('移除标签')),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      await change(name, null, () => widget.controller.deleteTag(name));
    }
  }

  Future<void> change(
    String oldName,
    String? newName,
    Future<int> Function() operation,
  ) async {
    setState(() => busy = true);
    try {
      final count = await operation();
      if (!mounted) return;
      widget.onTagChanged?.call(oldName, newName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('标签已更新，处理了 {count} 条记录', {'count': count})),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.t('管理标签')),
        actions: const [ArchiveLanguageSwitch()],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final all = widget.controller.knownTags;
          final names = all
              .where(
                (name) => name.toLowerCase().contains(
                  search.text.replaceFirst(RegExp(r'^[#＃]'), '').toLowerCase(),
                ),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('共 {count} 个历史标签 · 只属于自己的分类', {
                        'count': all.length,
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: search,
                      enabled: !busy,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: context.t('搜索历史标签'),
                      ),
                    ),
                  ],
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: names.isEmpty
                    ? Center(child: Text(context.t('还没有匹配的标签')))
                    : ListView(
                        children: [
                          for (final name in names)
                            ListTile(
                              leading: Transform(
                                transform: Matrix4.skewX(-0.18),
                                child: const Icon(Icons.tag),
                              ),
                              title: Text('#$name'),
                              enabled: !busy,
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TagRecordsPage(
                                    controller: widget.controller,
                                    tag: name,
                                  ),
                                ),
                              ),
                              subtitle: Text(
                                '${context.t('{count} 条记录使用', {'count': uses(name)})}${uses(name) == 0 ? context.t(' · 仍可再次选择') : ''}',
                              ),
                              trailing: PopupMenuButton<String>(
                                enabled: !busy,
                                tooltip: context.t('管理 #{name}', {
                                  'name': name,
                                }),
                                onSelected: (value) {
                                  if (value == 'rename') {
                                    rename(name);
                                  } else {
                                    remove(name);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(context.t('重命名 / 合并')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.t('移除标签')),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class TagRecordsPage extends StatefulWidget {
  const TagRecordsPage({
    super.key,
    required this.controller,
    required this.tag,
  });
  final ArchiveActions controller;
  final String tag;
  @override
  State<TagRecordsPage> createState() => _TagRecordsPageState();
}

class _TagRecordsPageState extends State<TagRecordsPage> {
  void open(Entry entry, String query) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (context) => entry.kind == 'material'
          ? MaterialDetail(controller: widget.controller, id: entry.id)
          : Scaffold(
              appBar: AppBar(title: Text(context.t('我的记录'))),
              body: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final current = widget.controller.entry(entry.id);
                  return current == null
                      ? Center(child: Text(context.t('这条记录已被删除')))
                      : EntryDetail(
                          entry: current,
                          controller: widget.controller,
                          query: query,
                          onEdit: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntryEditor(
                                controller: widget.controller,
                                entry: current,
                              ),
                            ),
                          ),
                        );
                },
              ),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('#${widget.tag}'),
      actions: const [ArchiveLanguageSwitch()],
    ),
    body: NotesBrowser(
      controller: widget.controller,
      tagScope: widget.tag,
      onOpen: open,
    ),
  );
}
