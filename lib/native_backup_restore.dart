import 'app_language.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'backup_archive.dart';
import 'controller.dart';
import 'passphrase_field.dart';
import 'ui_helpers.dart';

Future<void> restoreNativeBackup(
  BuildContext context,
  ArchiveController controller,
) async {
  try {
    if (!controller.canRestoreBackup) {
      throw StateError('只能恢复到同账号的本机空档案；原资料未改动。');
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty || !context.mounted) return;
    final file = files.single;
    if ((file.lengthSync() ?? 0) > BackupArchive.maxBytes) {
      throw const FormatException('请选择不超过 64 MiB 的完整加密备份');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > BackupArchive.maxBytes) {
        throw const FormatException('备份超过 64 MiB，原资料未改动');
      }
      bytes.add(chunk);
    }
    final archive = BackupArchive.decode(bytes.takeBytes());
    if (!context.mounted) return;
    final restored = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          NativeBackupRestoreDialog(controller: controller, archive: archive),
    );
    if (context.mounted && restored == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('完整备份已保存到本机。档案仍锁定，解锁后再与云端对账。'))),
      );
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

class NativeBackupRestoreDialog extends StatefulWidget {
  const NativeBackupRestoreDialog({
    super.key,
    required this.controller,
    required this.archive,
  });
  final ArchiveController controller;
  final BackupArchive archive;

  @override
  State<NativeBackupRestoreDialog> createState() =>
      _NativeBackupRestoreDialogState();
}

class _NativeBackupRestoreDialogState extends State<NativeBackupRestoreDialog> {
  final secret = TextEditingController();
  bool recovery = false, busy = false;
  String? failure;
  OpenedBackup? opened;

  @override
  void dispose() {
    secret.dispose();
    opened?.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      if (opened == null) {
        final verified = await widget.controller.verifyBackup(
          widget.archive,
          secret.text,
          recovery: recovery,
        );
        if (!mounted) {
          verified.dispose();
          return;
        }
        opened = verified;
        secret.clear();
      } else {
        await widget.controller.restoreBackup(opened!);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        failure = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : '备份验证或恢复未完成。输入已保留，请核对口令、恢复密钥与文件；原资料未改动。';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(context.t(opened == null ? '验证备份，尚未导入' : '恢复预览')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('恢复到当前登录邮箱：{email}', {
                  'email': widget.controller.email,
                }),
              ),
              const SizedBox(height: 16),
              if (opened == null) ...[
                PassphraseField(
                  controller: secret,
                  label: recovery ? '此备份的恢复密钥' : '此备份的加密口令',
                  enabled: !busy,
                  onSubmitted: (_) => submit(),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('使用恢复密钥')),
                  value: recovery,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => recovery = value ?? false),
                ),
                Text(context.t('仅支持 64 MiB 内的完整加密备份，不是“导出全部随笔”的明文 JSON。')),
              ] else ...[
                Text(
                  context.t(
                    '已验证 {records} 个对象（含删除标记）、{files} 份附件、{conflicts} 个待处理冲突。',
                    {
                      'records': widget.archive.records.length,
                      'files': widget.archive.files.length,
                      'conflicts': widget.archive.conflicts.length,
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.t(
                    '只恢复到本机空档案，不替换已有资料，不修改云端密钥。'
                    '恢复后保持锁定；主动解锁后，才按原同步规则处理云端新版本、删除和冲突。',
                  ),
                ),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (failure != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.t(failure!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(context.t('取消')),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(context.t(opened == null ? '验证并预览' : '确认恢复到本机空档案')),
        ),
      ],
    ),
  );
}
