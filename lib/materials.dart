import 'dart:typed_data';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'archive_actions.dart';
import 'app.dart' show EntryDetail;
import 'editor.dart';
import 'material_preview.dart';
import 'model.dart';
import 'tags.dart';
import 'ui_helpers.dart';
import 'app_language.dart';

const materialCategories = ['证件', '奖项', '经历证明', '作品', '其他'];

Future<void> setMaterialLink(
  ArchiveActions archive,
  String recordId,
  String materialId,
  bool linked,
) async {
  final record = archive.entry(recordId);
  if (record == null || !record.isRecord) throw StateError('记录已变更，请重新选择');
  if (linked && archive.entry(materialId)?.kind != 'material') {
    throw StateError('材料已变更，请重新选择');
  }
  if (record.materialIds.contains(materialId) == linked) return;
  final revision = archive.revisionOf(recordId);
  final delta = linked
      ? withMaterialReference(record.delta, materialId)
      : record.delta
            .where(
              (op) => materialReference((op as Map)['insert']) != materialId,
            )
            .toList();
  await archive.save(
    Entry.fromJson(record.id, {
      ...record.toJson(),
      'v': 2,
      'delta': delta,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }),
    baseRevision: revision,
  );
}

class MaterialsLibrary extends StatefulWidget {
  const MaterialsLibrary({super.key, required this.controller});
  final ArchiveActions controller;
  @override
  State<MaterialsLibrary> createState() => _MaterialsLibraryState();
}

class _MaterialsLibraryState extends State<MaterialsLibrary> {
  String query = '';
  String? category;
  bool loadingSample = false;

  Future<void> sample() async {
    setState(() => loadingSample = true);
    try {
      final asset = await rootBundle.load(
        'assets/samples/quiet-campus-sample.pdf',
      );
      final bytes = Uint8List.fromList(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      try {
        final file = await widget.controller.addAttachment('示例奖状.pdf', bytes);
        final now = DateTime.now();
        await widget.controller.save(
          Entry(
            id: const Uuid().v4(),
            kind: 'material',
            title: '示例奖状（虚构资料）',
            delta: const [
              {'insert': '仅供本机试用预览与关联，不含真实个人信息。\n'},
            ],
            materialCategory: '奖项',
            materialDate: DateTime(now.year, now.month, now.day),
            attachments: [file],
            createdAt: now,
            updatedAt: now,
          ),
          baseRevision: 0,
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => loadingSample = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t('材料库')),
      actions: const [ArchiveLanguageSwitch()],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialEditor(controller: widget.controller),
        ),
      ),
      icon: const Icon(Icons.add),
      label: Text(context.t('导入材料')),
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final rows = widget.controller.entries
            .where(
              (e) =>
                  e.kind == 'material' &&
                  (category == null || e.materialCategory == category) &&
                  e.matches(query),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
          children: [
            Text(context.t('把证件、奖项和作品留在自己的档案里。原件只存一份，可以关联多段经历。')),
            const SizedBox(height: 16),
            if (widget.controller.isDemo)
              OutlinedButton.icon(
                onPressed: loadingSample ? null : sample,
                icon: const Icon(Icons.science_outlined),
                label: Text(context.t('加入虚构的示例 PDF')),
              ),
            TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: context.t('搜索名称、说明、标签或分类'),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final name in ['全部', ...materialCategories])
                  ChoiceChip(
                    label: Text(context.t(name)),
                    selected: category == (name == '全部' ? null : name),
                    onSelected: (_) =>
                        setState(() => category = name == '全部' ? null : name),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(context.t('{count} 份材料', {'count': rows.length})),
            if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(context.t('还没有匹配的材料。支持图片与 PDF，每份最多 20 MiB。')),
              ),
            for (final e in rows)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(
                    e.attachments.firstOrNull?.name.toLowerCase().endsWith(
                              '.pdf',
                            ) ==
                            true
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(e.title),
                  subtitle: Text(
                    '${context.t(e.materialCategory)} · ${e.materialDate == null ? context.t('未设置日期') : '${e.materialDate!.year}.${e.materialDate!.month}.${e.materialDate!.day}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaterialDetail(
                        controller: widget.controller,
                        id: e.id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class MaterialEditor extends StatefulWidget {
  const MaterialEditor({super.key, required this.controller, this.entry});
  final ArchiveActions controller;
  final Entry? entry;
  @override
  State<MaterialEditor> createState() => _MaterialEditorState();
}

class _MaterialEditorState extends State<MaterialEditor> {
  late final name = TextEditingController(text: widget.entry?.title ?? '');
  late final description = TextEditingController(
    text: widget.entry?.plainText.trimRight() ?? '',
  );
  final input = TextEditingController();
  late List<String> tags = [...?widget.entry?.tags];
  late String category = widget.entry?.materialCategory ?? '其他';
  late DateTime? date = widget.entry?.materialDate ?? DateTime.now();
  late Attachment? file = widget.entry?.attachments.firstOrNull;
  late int revision = widget.entry == null
      ? 0
      : widget.controller.revisionOf(widget.entry!.id);
  bool busy = false, changed = false, allowPop = false;

  Future<void> manageTags() async {
    final id = widget.entry?.id;
    final before = id == null ? null : widget.controller.entry(id)?.toJson();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TagManager(
          controller: widget.controller,
          onTagChanged: (oldName, newName) {
            if (!mounted) return;
            setState(() {
              tags = tags
                  .map((name) => name == oldName ? newName : name)
                  .whereType<String>()
                  .toSet()
                  .toList();
              try {
                final pending = parseTagNames(input.text);
                if (pending.contains(oldName)) {
                  tags = {
                    ...tags,
                    ...pending
                        .map((name) => name == oldName ? newName : name)
                        .whereType<String>(),
                  }.toList();
                  input.clear();
                }
              } on FormatException {
                /* Keep invalid draft input for correction. */
              }
              changed = true;
            });
          },
        ),
      ),
    );
    if (!mounted) return;
    final after = id == null ? null : widget.controller.entry(id)?.toJson();
    if (before != null && after != null) {
      for (final json in [before, after]) {
        json.remove('tags');
        json.remove('updatedAt');
      }
      if (jsonEncode(before) == jsonEncode(after)) {
        revision = widget.controller.revisionOf(id!);
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final field in [name, description, input]) {
      field.addListener(() {
        changed = true;
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy) return;
    if (changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t('放弃尚未保存的材料？')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('继续编辑')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t('放弃修改')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
      );
      if (selected.isEmpty) return;
      final source = selected.first;
      if (!isMaterialFile(source.name)) {
        throw const FormatException('请选择图片或 PDF');
      }
      final chunks = BytesBuilder(copy: false);
      await for (final chunk in source.readAsByteStream()) {
        if (chunks.length + chunk.length > 20 * 1024 * 1024) {
          throw const FormatException('单份材料最多 20 MiB');
        }
        chunks.add(chunk);
      }
      final bytes = chunks.takeBytes();
      try {
        if (bytes.isEmpty) throw const FormatException('文件为空');
        final attachment = await widget.controller.addAttachment(
          source.name,
          bytes,
        );
        if (mounted && widget.controller.unlocked) {
          setState(() {
            file = attachment;
            changed = true;
            if (name.text.isEmpty) name.text = source.name;
          });
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        /* Desktop pickers may not cache files. */
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (file == null || name.text.trim().isEmpty) {
        throw const FormatException('请选择原件并填写材料名称');
      }
      final now = DateTime.now();
      await widget.controller.save(
        Entry(
          id: widget.entry?.id ?? const Uuid().v4(),
          kind: 'material',
          title: name.text.trim(),
          delta: [
            {'insert': '${description.text.trimRight()}\n'},
          ],
          attachments: [file!],
          tags: {...tags, ...parseTagNames(input.text)}.toList(),
          materialCategory: category,
          materialDate: date,
          createdAt: widget.entry?.createdAt ?? now,
          updatedAt: now,
        ),
        baseRevision: revision,
      );
      if (!mounted) return;
      setState(() {
        changed = false;
        allowPop = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop || !changed && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('返回'),
          onPressed: busy ? null : close,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.entry == null ? context.t('导入材料') : context.t('编辑材料'),
        ),
        actions: [
          const ArchiveLanguageSwitch(),
          TextButton(
            onPressed: busy ? null : save,
            child: Text(context.t('保存材料')),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.controller.isDemo
                      ? context.t('演示仅保留在本页内存；请选择示例文件。')
                      : context.t('原件、名称和说明沿用档案加密保存。'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: pick,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    file == null
                        ? context.t('选择图片或 PDF · 最多 20 MiB')
                        : '更换原件：${file!.name}',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  maxLength: 200,
                  decoration: InputDecoration(labelText: context.t('材料名称')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: context.t('分类')),
                  items: [
                    for (final value in materialCategories)
                      DropdownMenuItem(
                        value: value,
                        child: Text(context.t(value)),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    category = value!;
                    changed = true;
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('材料日期')),
                  subtitle: Text(
                    date == null
                        ? context.t('未设置')
                        : '${date!.year} 年 ${date!.month} 月 ${date!.day} 日',
                  ),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (selected != null && mounted) {
                      setState(() {
                        date = selected;
                        changed = true;
                      });
                    }
                  },
                ),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: context.t('说明（可选）')),
                ),
                const SizedBox(height: 16),
                TagPicker(
                  input: input,
                  selected: tags,
                  history: widget.controller.knownTags,
                  onManage: manageTags,
                  onChanged: (value) => setState(() {
                    tags = value;
                    changed = true;
                  }),
                ),
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MaterialDetail extends StatelessWidget {
  const MaterialDetail({super.key, required this.controller, required this.id});
  final ArchiveActions controller;
  final String id;

  Future<void> link(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('关联经历或项目')),
        content: SizedBox(
          width: 480,
          height: 320,
          child: ListView(
            children: [
              for (final e in controller.entries.where(
                (e) =>
                    ['experience', 'project'].contains(e.kind) &&
                    !e.materialIds.contains(id),
              ))
                ListTile(
                  title: Text(e.title.isEmpty ? context.t('无题记录') : e.title),
                  subtitle: Text(context.t(e.kindLabel)),
                  onTap: () => Navigator.pop(context, e.id),
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
      ),
    );
    if (selected == null) return;
    try {
      await setMaterialLink(controller, selected, id, true);
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final e = controller.entry(id);
      if (e == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.t('材料'))),
          body: Center(
            child: Text(
              controller.isDeleted(id)
                  ? context.t('材料已删除，记录中的引用仍保留。')
                  : context.t('材料尚未同步或无法读取。'),
            ),
          ),
        );
      }
      final links = controller.entries
          .where((record) => record.isRecord && record.materialIds.contains(id))
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(context.t('材料档案')),
          actions: const [ArchiveLanguageSwitch()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              '${context.t(e.materialCategory)} · ${e.materialDate == null ? context.t('未设置日期') : '${e.materialDate!.year}.${e.materialDate!.month}.${e.materialDate!.day}'}',
            ),
            Wrap(
              spacing: 8,
              children: [for (final tag in e.tags) Chip(label: Text('#$tag'))],
            ),
            Text(e.plainText),
            for (final file in e.attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(file.name),
                subtitle: Text(
                  '${(file.size / 1024).ceil()} KB · ${context.t('点击预览')}',
                ),
                onTap: () => previewMaterial(context, controller, file),
              ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MaterialEditor(controller: controller, entry: e),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.t('编辑材料')),
                ),
                FilledButton.icon(
                  onPressed: () => link(context),
                  icon: const Icon(Icons.link),
                  label: Text(context.t('关联经历或项目')),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              '关联的记录 · ${links.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (links.isEmpty) Text(context.t('也可以在任意随笔的编辑器里插入材料引用。')),
            for (final record in links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  record.title.isEmpty ? context.t('无题记录') : record.title,
                ),
                subtitle: Text(context.t(record.kindLabel)),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text(context.t('关联记录'))),
                      body: ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) {
                          final current = controller.entry(record.id);
                          if (current == null) {
                            return Center(child: Text(context.t('这条记录已被删除')));
                          }
                          return EntryDetail(
                            entry: current,
                            controller: controller,
                            onEdit: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EntryEditor(
                                  controller: controller,
                                  entry: current,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                trailing: IconButton(
                  tooltip: context.t('解除关联（保留记录和原件）'),
                  icon: const Icon(Icons.link_off),
                  onPressed: () async {
                    try {
                      await setMaterialLink(controller, record.id, id, false);
                    } catch (error) {
                      if (context.mounted) showFailure(context, error);
                    }
                  },
                ),
              ),
            const SizedBox(height: 24),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(context.t('删除材料')),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.t('删除这份材料？')),
                    content: Text(
                      '${context.t('{count} 条记录引用它。记录和引用会保留并显示“材料已删除”。已有密文暂不物理清理。', {'count': links.length})}\n${context.t(controller.deletionNotice)}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.t('保留')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.t('删除材料')),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await controller.deleteEntry(e);
                  } catch (error) {
                    if (context.mounted) showFailure(context, error);
                  }
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
