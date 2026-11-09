import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ui_helpers.dart';
import 'archive_actions.dart';
import 'editor.dart';
import 'model.dart';
import 'theme.dart';
import 'calendar_export.dart';
import 'record_search.dart';
import 'search_highlight.dart';
import 'record_export.dart';
import 'material_embed.dart';
import 'material_preview.dart';
import 'audio_notes.dart';
export 'archive_home.dart';
import 'app_language.dart';

class EntryDetail extends StatelessWidget {
  const EntryDetail({
    super.key,
    required this.entry,
    required this.controller,
    required this.onEdit,
    this.query = '',
  });
  final Entry entry;
  final ArchiveActions controller;
  final VoidCallback onEdit;
  final String query;
  @override
  Widget build(BuildContext context) {
    final hit = entry.search(query, displayKind: context.t(entry.kindLabel));
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HighlightedText(
                entry.title.isEmpty ? context.t('无题记录') : entry.title,
                hit?.title ?? [],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: context.t('编辑'),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: context.t('删除记录'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.t('删除这条记录？')),
                    content: Text(context.t(controller.deletionNotice)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.t('保留')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.t('删除')),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await controller.deleteEntry(entry);
                  } catch (error) {
                    if (context.mounted) showFailure(context, error);
                  }
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(dateLabel(entry.createdAt)),
            const SizedBox(width: 10),
            HighlightedText(context.t(entry.kindLabel), hit?.kind ?? []),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => exportNotes(context, [entry], single: entry),
            icon: const Icon(Icons.download_outlined),
            label: Text(context.t('导出明文文本')),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < entry.tags.length; i++)
              Chip(
                label: HighlightedText('#${entry.tags[i]}', [
                  for (final range in hit?.tags[i] ?? <MatchRange>[])
                    (start: range.start + 1, end: range.end + 1),
                ]),
              ),
          ],
        ),
        if (entry.kind == 'activity') ...[
          if (entry.startsAt != null)
            Text(
              '${context.t('日程：')}${dateLabel(entry.startsAt!)}${entry.endsAt == null ? '' : ' — ${dateLabel(entry.endsAt!)}'}',
            ),
          if (entry.scheduleDate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: entry.status == ActivityStatus.cancelled
                    ? null
                    : () => exportToCalendar(context, entry),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(context.t('添加到系统日历')),
              ),
            ),
          Text(context.t(entry.status.label)),
          if (entry.deadline != null)
            Text('${context.t('报名截止：')}${dateLabel(entry.deadline!)}'),
          if (entry.role.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: HighlightedText('${context.t('承担的工作：')}${entry.role}', [
                for (final range in hit?.role ?? <MatchRange>[])
                  (
                    start: range.start + context.t('承担的工作：').length,
                    end: range.end + context.t('承担的工作：').length,
                  ),
              ]),
            ),
        ],
        if (entry.activityId != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${context.t('关联活动：')}${controller.entry(entry.activityId!)?.title ?? context.t('原活动已删除')}',
            ),
          ),
        if (entry.reminder != null)
          Text('${context.t('提醒：')}${dateLabel(entry.reminder!)}'),
        const SizedBox(height: 20),
        ReadOnlyDocument(
          key: ValueKey('${entry.id}:${entry.updatedAt}'),
          delta: entry.delta,
          archive: controller,
          highlights: hit?.body ?? [],
        ),
        if (entry.attachments.isNotEmpty) ...[
          const Divider(height: 40),
          Text(
            context.t('留下的材料'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...entry.attachments.map(
            (file) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isAudioFile(file.name)
                    ? Icons.play_circle_outline
                    : Icons.description_outlined,
              ),
              title: Text(file.name),
              subtitle: Text('${(file.size / 1024).ceil()} KB'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => previewAttachment(context, controller, file),
            ),
          ),
        ],
      ],
    );
  }
}

class ReadOnlyDocument extends StatefulWidget {
  const ReadOnlyDocument({
    super.key,
    required this.delta,
    this.highlights = const [],
    this.archive,
  });
  final List<dynamic> delta;
  final List<MatchRange> highlights;
  final ArchiveActions? archive;
  @override
  State<ReadOnlyDocument> createState() => _ReadOnlyDocumentState();
}

class _ReadOnlyDocumentState extends State<ReadOnlyDocument> {
  late final controller = QuillController(
    document: Document.fromJson(widget.delta),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranges = documentMatchRanges(widget.delta, widget.highlights);
    return QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        embedBuilders: [
          if (widget.archive != null) MaterialEmbedBuilder(widget.archive!),
        ],
        unknownEmbedBuilder: const UnknownArchiveEmbedBuilder(),
        customStyles: archiveDocumentStyles(context),
        textSpanBuilder: (context, node, nodeOffset, text, style, recognizer) =>
            highlightedSpan(
              text,
              ranges,
              offset: node.documentOffset + nodeOffset,
              style: style,
              recognizer: recognizer,
            ),
        scrollable: false,
        padding: EdgeInsets.zero,
        showCursor: false,
      ),
    );
  }
}

Future<void> previewAttachment(
  BuildContext context,
  ArchiveActions controller,
  Attachment file,
) async {
  if (isAudioFile(file.name)) {
    await playOriginalAudio(context, controller, file);
    return;
  }
  if (isMaterialFile(file.name)) {
    await previewMaterial(context, controller, file);
    return;
  }
  Uint8List? bytes;
  try {
    final extension = p.extension(file.name).toLowerCase();
    final image = [
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.gif',
    ].contains(extension);
    if (!image &&
        ![
          '.pdf',
          '.txt',
          '.docx',
          '.xlsx',
          '.pptx',
          '.odt',
          '.ods',
          '.odp',
          '.csv',
        ].contains(extension)) {
      bytes = await controller.readAttachment(file);
      await saveBytes(file.name, bytes);
      return;
    }
    if (!image && kIsWeb) {
      bytes = await controller.readAttachment(file);
      await saveBytes(file.name, bytes);
      return;
    }
    if (!image) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.t('交给其他应用预览？')),
          content: Text(context.t('会生成一份本机解密副本，并交给你选择的应用打开。预览缓存会在静档下次启动时清理。')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t('继续')),
            ),
          ],
        ),
      );
      if (open != true) return;
    }
    bytes = await controller.readAttachment(file);
    if (!context.mounted) return;
    if (image) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(file.name),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.t('关闭预览'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes!,
                    errorBuilder: (_, error, stack) => Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(context.t('无法显示这张图片')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final dir = Directory(
        p.join(
          (await getTemporaryDirectory()).path,
          'quiet-campus-preview',
          file.id,
        ),
      );
      await dir.create(recursive: true);
      final path = p.join(dir.path, p.basename(file.name));
      await File(path).writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        throw StateError('没有可用的预览应用，请安装对应的文件查看器');
      }
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  } finally {
    bytes?.fillRange(0, bytes.length, 0);
  }
}

class ConflictsPage extends StatelessWidget {
  const ConflictsPage({super.key, required this.controller});
  final ArchiveActions controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('保留下来的两个版本'))),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: controller.conflicts.keys.map((id) {
          final local = controller.entry(id);
          final remote = controller.conflictEntry(id);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('本机版本'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(local?.title ?? context.t('本机已删除')),
                  if (local != null) Text(local.plainText),
                  const Divider(height: 28),
                  Text(
                    context.t('云端版本'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(remote?.title ?? context.t('云端已删除')),
                  if (remote != null) Text(remote.plainText),
                  if (remote == null && local != null)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(context.t('选择本机版本会恢复这条记录。')),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          try {
                            await controller.resolve(id, true);
                          } catch (error) {
                            if (context.mounted) showFailure(context, error);
                          }
                        },
                        child: Text(context.t('使用本机版本')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await controller.resolve(id, false);
                          } catch (error) {
                            if (context.mounted) showFailure(context, error);
                          }
                        },
                        child: Text(context.t('使用云端版本')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}
