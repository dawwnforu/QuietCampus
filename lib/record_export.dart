import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'model.dart';
import 'ui_helpers.dart';
import 'app_language.dart';

String recordText(Entry entry) =>
    '${entry.title}\n${entry.createdAt.toLocal().toIso8601String()} · ${entry.kindLabel}\n'
    '${entry.tags.map((tag) => '#$tag').join(' ')}\n\n${entry.delta.map((op) {
      final insert = (op as Map)['insert'];
      final id = materialReference(insert);
      return insert is String
          ? insert
          : id == null
          ? '[嵌入内容：请用原客户端查看]'
          : '[材料引用：$id（原件不随文本导出）]';
    }).join()}';

String recordsJson(Iterable<Entry> entries) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': 'quiet-campus-notes-v1',
      'records': [
        for (final entry in entries.where((entry) => entry.isRecord))
          {'id': entry.id, ...entry.toJson()},
      ],
    });

Future<void> exportNotes(
  BuildContext context,
  Iterable<Entry> entries, {
  Entry? single,
}) async {
  final records = entries.where((entry) => entry.isRecord).toList();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        single == null
            ? context.t('导出全部 {count} 篇随笔？', {'count': records.length})
            : context.t('导出这篇记录？'),
      ),
      content: Text(
        single == null
            ? context.t(
                '导出全部日记、经历和项目，不受搜索、分类或已显示数量影响。JSON 保留富文本、材料引用及附件信息，不含材料库元数据与原件。文件是明文；完整材料请使用设置中的加密备份。',
              )
            : context.t('导出标题、日期、类型、标签和正文为明文文本，材料仅导出引用标记，不含搜索高亮与原件。'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.t('选择保存位置')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final text = single == null ? recordsJson(records) : recordText(single);
    await saveBytes(
      single == null ? '静档全部随笔.json' : '静档记录.txt',
      Uint8List.fromList(utf8.encode(text)),
    );
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}
