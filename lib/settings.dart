import 'app_language.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;

import 'auth_pages.dart';
import 'controller.dart';
import 'passphrase_field.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final ArchiveController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  ArchiveController get c => widget.controller;
  Future<void> action(Future<void> Function() run) async {
    setState(() => busy = true);
    try {
      await run();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> password() async {
    final key = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangePassphraseDialog(onUpdate: c.changePassword),
    );
    if (key != null && mounted) await showRecovery(context, key);
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('删除整个账号和云端档案？')),
        content: Text(
          context.t(
            '云端记录、附件和密钥封装将被删除。其他离线设备及你自己导出的文件仍需自行清理。此操作无法撤销，建议先导出加密备份。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('保留账号')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('发送验证码以删除')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await c.client.auth.signInWithOtp(email: c.email, shouldCreateUser: false);
    if (!mounted) return;
    final code = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('确认是本人操作')),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.t('邮箱中的验证码')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, code.text),
            child: Text(context.t('永久删除')),
          ),
        ],
      ),
    );
    code.dispose();
    if (token != null && token.trim().isNotEmpty) {
      await c.deleteAccount(token);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t('我的设置')),
      actions: const [ArchiveLanguageSwitch()],
    ),
    body: AbsorbPointer(
      absorbing: busy,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AccountPanel(controller: c, enabled: !busy),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('开启系统提醒')),
            subtitle: Text(context.t('只提醒你主动设置的事项，通知默认隐藏具体内容。')),
            value: c.notificationsEnabled,
            onChanged: (value) => action(() async {
              if (!await c.enableNotifications(value)) {
                throw StateError('通知权限未开启，安排仍保存在应用中');
              }
            }),
          ),
          if (defaultTargetPlatform == TargetPlatform.android)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_outlined),
              title: Text(context.t('安卓精确提醒（可选）')),
              subtitle: Text(
                context.t('前往系统授权准时提醒。未授权时使用普通通知；静音、勿扰和设备限制仍可能影响声音。'),
              ),
              onTap: () => action(() async {
                final allowed = await c.reminders.requestExactPermission();
                await c.reminders.reconcile(
                  c.entries,
                  enabled: c.notificationsEnabled,
                );
                if (!allowed) throw StateError('未开启精确提醒，继续使用普通通知');
              }),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: Text(context.t('重新设置口令和恢复密钥')),
            onTap: () => action(password),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(context.t('导出完整加密备份')),
            subtitle: Text(context.t('包含记录、冲突版本和附件；不包含明文密钥。')),
            onTap: () => action(() async {
              final bytes = await c.backup();
              final saved = await saveBytes('quiet-campus-backup.json', bytes);
              if (context.mounted && saved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('加密备份已保存，请同时保管口令或恢复密钥。'))),
                );
              }
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(context.t('锁定档案')),
            onTap: () {
              c.lock();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(context.t('退出账号并清除本机缓存')),
            onTap: () => action(() async {
              await c.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }),
          ),
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_outlined),
            title: Text(context.t('删除账号和云端档案')),
            onTap: () => action(delete),
          ),
          const SizedBox(height: 24),
          Text(
            '${context.t('静档')} 0.2.5 · '
            '${context.t(ArchiveLanguageScope.of(context)?.editionLabel ?? '云同步测试版')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: context.t('静档'),
              applicationVersion: '0.2.5',
            ),
            child: Text(context.t('开源许可')),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}

class ChangePassphraseDialog extends StatefulWidget {
  const ChangePassphraseDialog({super.key, required this.onUpdate});
  final Future<String> Function(String) onUpdate;
  @override
  State<ChangePassphraseDialog> createState() => _ChangePassphraseDialogState();
}

class _ChangePassphraseDialogState extends State<ChangePassphraseDialog> {
  final form = GlobalKey<FormState>();
  final secret = TextEditingController();
  final confirm = TextEditingController();
  bool saving = false;
  String? failure;

  @override
  void dispose() {
    secret.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> update() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      final recovery = await widget.onUpdate(secret.text);
      if (mounted) Navigator.pop(context, recovery);
    } catch (_) {
      if (mounted) setState(() => failure = '更新未完成，输入已保留，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(context.t('重新设置加密口令')),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('需要联网。成功后将生成新的恢复密钥，请重新保存。')),
                const SizedBox(height: 16),
                PassphraseField(
                  controller: secret,
                  label: '新加密口令',
                  enabled: !saving,
                  newPassphrase: true,
                  validator: validateNewPassphrase,
                ),
                const SizedBox(height: 12),
                PassphraseField(
                  controller: confirm,
                  label: '再次输入新口令',
                  enabled: !saving,
                  validator: (value) =>
                      value != secret.text ? '两次加密口令不一致，请修改后重试' : null,
                  onSubmitted: (_) => update(),
                ),
                if (failure != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.t(failure!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(context.t('取消')),
        ),
        FilledButton(
          onPressed: saving ? null : update,
          child: Text(context.t(saving ? '更新中…' : '更新')),
        ),
      ],
    ),
  );
}
