import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'archive_actions.dart';
import 'model.dart';
import 'material_preview.dart';
import 'app_language.dart';

class MaterialEmbedBuilder extends EmbedBuilder {
  const MaterialEmbedBuilder(this.archive);
  final ArchiveActions archive;
  @override
  String get key => materialEmbedType;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final id = embedContext.node.value.data;
    return ListenableBuilder(
      listenable: archive,
      builder: (context, _) {
        final material = id is String ? archive.entry(id) : null;
        final available =
            archive.unlocked &&
            material?.kind == 'material' &&
            material!.attachments.length == 1;
        return Card(
          color: const Color(0xffeef3ef),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              available
                  ? material.title
                  : archive.isDeleted('$id')
                  ? context.t('材料已删除')
                  : context.t('材料暂不可用'),
            ),
            subtitle: Text(
              available
                  ? '${context.t(material.materialCategory)} · ${context.t('点击预览原件')}'
                  : context.t('引用仍保留；材料可能尚未同步，或已经删除。'),
            ),
            onTap: available
                ? () => previewMaterial(
                    context,
                    archive,
                    material.attachments.single,
                  )
                : null,
            trailing: embedContext.readOnly
                ? null
                : IconButton(
                    tooltip: context.t('解除此处关联（保留材料）'),
                    icon: const Icon(Icons.link_off),
                    onPressed: () => embedContext.controller.replaceText(
                      embedContext.node.documentOffset,
                      1,
                      '',
                      null,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class UnknownArchiveEmbedBuilder extends EmbedBuilder {
  const UnknownArchiveEmbedBuilder();
  @override
  String get key => 'unknown';
  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Padding(
    padding: EdgeInsets.all(16),
    child: Text(context.t('此内容需要更新客户端后查看；原始嵌入内容仍保留。')),
  );
}

Future<String?> chooseMaterial(
  BuildContext context,
  ArchiveActions archive,
) async {
  var query = '';
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(context.t('引用材料库原件')),
        content: SizedBox(
          width: 480,
          height: 360,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: context.t('搜索材料名称、说明或标签'),
                ),
                onChanged: (value) => update(() => query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: archive,
                  builder: (context, _) {
                    final rows = archive.entries
                        .where((e) => e.kind == 'material' && e.matches(query))
                        .toList();
                    if (rows.isEmpty) {
                      return Center(
                        child: Text(context.t('还没有匹配的材料，可先到档案 → 材料库导入。')),
                      );
                    }
                    return ListView(
                      children: [
                        for (final e in rows)
                          ListTile(
                            title: Text(e.title),
                            subtitle: Text(context.t(e.materialCategory)),
                            onTap: () => Navigator.pop(context, e.id),
                          ),
                      ],
                    );
                  },
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
      ),
    ),
  );
}
