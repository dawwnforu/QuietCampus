import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'archive_actions.dart';
import 'model.dart';
import 'app_language.dart';

bool isMaterialFile(String name) =>
    RegExp(r'\.(pdf|png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(name);

Future<void> previewMaterial(
  BuildContext context,
  ArchiveActions controller,
  Attachment file,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => MaterialPreview(controller: controller, file: file),
  ),
);

class MaterialPreview extends StatefulWidget {
  const MaterialPreview({
    super.key,
    required this.controller,
    required this.file,
  });
  final ArchiveActions controller;
  final Attachment file;
  @override
  State<MaterialPreview> createState() => _MaterialPreviewState();
}

class _MaterialPreviewState extends State<MaterialPreview> {
  Uint8List? bytes;
  MemoryImage? image;
  bool loading = true;
  int attempt = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(checkLock);
    load();
  }

  void checkLock() {
    if (!widget.controller.unlocked) {
      attempt++;
      clear();
      if (mounted) {
        setState(() {
          loading = false;
          error = '档案已锁定';
        });
      }
    }
  }

  void clear() {
    image?.evict();
    image = null;
    bytes?.fillRange(0, bytes!.length, 0);
    bytes = null;
  }

  Future<void> load() async {
    final request = ++attempt;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.controller.readAttachment(widget.file);
      if (!mounted || request != attempt || !widget.controller.unlocked) {
        data.fillRange(0, data.length, 0);
        return;
      }
      setState(() {
        bytes = data;
        if (!widget.file.name.toLowerCase().endsWith('.pdf')) {
          image = MemoryImage(data);
        }
        loading = false;
      });
    } catch (_) {
      if (mounted && request == attempt) {
        setState(() {
          loading = false;
          error = '原件暂未下载或无法读取。联网后可重试，本机记录仍保留。';
        });
      }
    }
  }

  @override
  void dispose() {
    attempt++;
    widget.controller.removeListener(checkLock);
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.controller.unlocked ? widget.file.name : context.t('预览已关闭'),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t(error!)),
                  if (widget.controller.unlocked)
                    TextButton(onPressed: load, child: Text(context.t('重试下载'))),
                ],
              ),
            ),
          )
        : image != null
        ? Center(
            child: InteractiveViewer(
              child: Image(
                image: image!,
                errorBuilder: (_, _, _) => Text(context.t('图片格式损坏或不受支持')),
              ),
            ),
          )
        : PdfViewer.data(
            bytes!,
            sourceName: widget.file.id,
            maxSizeToCacheOnMemory: 20 * 1024 * 1024,
            params: PdfViewerParams(
              linkHandlerParams: PdfLinkHandlerParams(onLinkTap: (_) {}),
              errorBannerBuilder: (_, _, _, _) =>
                  Center(child: Text(context.t('无法打开此 PDF，请检查文件是否损坏或需要密码'))),
            ),
          ),
  );
}
