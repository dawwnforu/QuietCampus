import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';
import 'file_save_options.dart'
    if (dart.library.js_interop) 'file_save_options_web.dart';

void showFailure(BuildContext context, Object error) {
  final message = error is FormatException
      ? error.message
      : error is StateError
      ? error.message.toString()
      : '操作未完成。请检查网络或输入后重试，已有记录不会被清除。';
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.t(message))));
}

Future<bool> saveBytes(String name, Uint8List bytes) async {
  final path = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    webOptions: browserSaveOptions,
  );
  if (path == null) return false;
  return true;
}

class BackupDownloadConfirmation extends StatefulWidget {
  const BackupDownloadConfirmation({
    super.key,
    required this.download,
    required this.onConfirmed,
  });
  final Future<void> Function() download;
  final ValueChanged<bool> onConfirmed;
  @override
  State<BackupDownloadConfirmation> createState() =>
      _BackupDownloadConfirmationState();
}

class _BackupDownloadConfirmationState
    extends State<BackupDownloadConfirmation> {
  bool requested = false, confirmed = false, busy = false;
  Future<void> download() async {
    setState(() {
      busy = true;
      requested = false;
      confirmed = false;
    });
    widget.onConfirmed(false);
    try {
      await widget.download();
      if (mounted) setState(() => requested = true);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: busy ? null : download,
        icon: const Icon(Icons.download_outlined),
        label: Text(context.t('先导出当前完整加密备份')),
      ),
      if (busy) const LinearProgressIndicator(),
      if (requested) ...[
        Text(context.t('已请求保存，请核对文件确实存在并安全另存。下载请求不代表备份成功。')),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('我已核对并保存当前档案的完整加密备份')),
          value: confirmed,
          onChanged: (value) {
            setState(() => confirmed = value ?? false);
            widget.onConfirmed(confirmed);
          },
        ),
      ],
    ],
  );
}

Future<void> showRecovery(BuildContext context, String recovery) async {
  var saved = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(context.t('把恢复密钥留在自己手里')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      '忘记加密口令时，可以用它找回档案。请存到安全的离线位置。口令、恢复密钥和可用旧设备都丢失后，我们也无法恢复内容。',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SelectableText(
                    recovery,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text(context.t('保存恢复密钥文件')),
                    onPressed: () async {
                      try {
                        await saveBytes(
                          'quiet-campus-recovery.txt',
                          Uint8List.fromList(utf8.encode(recovery)),
                        );
                      } catch (error) {
                        if (context.mounted) showFailure(context, error);
                      }
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('我已另行保存恢复密钥')),
                    value: saved,
                    onChanged: (v) => setState(() => saved = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: saved ? () => Navigator.pop(context) : null,
              child: Text(context.t('继续')),
            ),
          ],
        ),
      ),
    ),
  );
}
