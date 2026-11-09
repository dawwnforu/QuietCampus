import 'app_language.dart';
import 'ui_helpers.dart';
export 'ui_helpers.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller.dart';
import 'passphrase_field.dart';
import 'native_backup_restore.dart';

class AccountPanel extends StatefulWidget {
  const AccountPanel({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final ArchiveController controller;
  final bool enabled;
  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  bool switching = false;

  Future<void> switchAccount() async {
    if (switching) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('切换登录账号？')),
        content: Text(
          context.t(
            '将锁定当前档案并返回邮箱登录。各账号资料独立，不会合并。'
            '本机密文、未同步修改和冲突版本会保留；切回原邮箱并解锁后才能继续同步。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('留在当前账号')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('切换账号')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => switching = true);
    try {
      await widget.controller.switchAccount();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => switching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('当前登录邮箱'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SelectableText(widget.controller.email),
            Text(
              context.t(
                ArchiveLanguageScope.of(context)?.editionLabel ?? '云同步测试版',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
        final button = TextButton(
          onPressed: widget.enabled && !switching ? switchAccount : null,
          child: Text(context.t(switching ? '切换中…' : '切换账号')),
        );
        if (constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 8), button],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final ArchiveController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  bool sent = false;
  bool busy = false;
  String? sentTo;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!sent) {
        final address = email.text.trim();
        if (!address.contains('@')) throw const FormatException('请输入有效的邮箱地址');
        await widget.controller.client.auth.signInWithOtp(email: address);
        if (mounted) {
          setState(() {
            sent = true;
            sentTo = address;
          });
        }
      } else {
        await widget.controller.client.auth.verifyOTP(
          email: sentTo,
          token: code.text.trim(),
          type: OtpType.email,
        );
        await widget.controller.openAccount();
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.spa_outlined, size: 48),
                    Spacer(),
                    ArchiveLanguageSwitch(),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  context.t('静档'),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('你的经历，留给自己。'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(context.t('记下一点想法，留住一次参与。没有公开主页，也没有需要回应的动态。')),
                const SizedBox(height: 36),
                TextField(
                  controller: email,
                  enabled: !busy && !sent,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.t('邮箱'),
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                if (sent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: code,
                    enabled: !busy,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('邮件中的验证码'),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      context.t(
                        busy
                            ? '请稍候…'
                            : sent
                            ? '进入我的档案'
                            : '发送验证码',
                      ),
                    ),
                  ),
                ),
                if (sent)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            sent = false;
                            code.clear();
                          }),
                    child: Text(context.t('重新发送或更换邮箱')),
                  ),
                const SizedBox(height: 20),
                Text(
                  context.t('首次使用将创建私人账号。验证码只用于登录，加密口令会在下一步设置。'),
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key, required this.controller});
  final ArchiveController controller;
  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final form = GlobalKey<FormState>();
  final secret = TextEditingController();
  final confirm = TextEditingController();
  bool recovery = false;
  bool busy = false;
  String? failure;
  @override
  void dispose() {
    secret.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit({bool device = false}) async {
    if (busy || (!device && !form.currentState!.validate())) return;
    final navigatorContext = Navigator.of(context).context;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      if (widget.controller.needsSetup) {
        final key = await widget.controller.createVault(secret.text);
        if (mounted) {
          secret.clear();
          confirm.clear();
        }
        if (navigatorContext.mounted) await showRecovery(navigatorContext, key);
      } else if (device) {
        await widget.controller.unlockDevice();
      } else {
        await widget.controller.unlock(secret.text, recovery: recovery);
      }
      if (mounted) {
        secret.clear();
        confirm.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = widget.controller.needsSetup
              ? '创建未完成，输入已保留，请检查网络后重试；若已在其他设备创建，请重新连接账号。'
              : device
              ? '本机密钥暂不可用，请改用加密口令或恢复密钥。'
              : '无法解锁，输入已保留，请检查口令或恢复密钥。',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.controller.needsSetup;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 44),
                      Spacer(),
                      ArchiveLanguageSwitch(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.t(setup ? '建立你的私人档案' : '欢迎回来'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t(
                      setup
                          ? '设置独立加密口令，用于解密档案。邮箱验证码负责登录；其他设备需用同一邮箱和加密口令。'
                          : '输入独立加密口令解锁自己的档案。',
                    ),
                  ),
                  AccountPanel(controller: widget.controller, enabled: !busy),
                  const SizedBox(height: 28),
                  PassphraseField(
                    key: ValueKey(recovery),
                    controller: secret,
                    enabled: !busy,
                    label: recovery ? '恢复密钥' : '加密口令',
                    newPassphrase: setup,
                    validator: setup
                        ? validateNewPassphrase
                        : (value) => (value ?? '').isEmpty
                              ? '请输入${recovery ? '恢复密钥' : '加密口令'}'
                              : null,
                    onSubmitted: (_) => submit(),
                  ),
                  if (setup) ...[
                    const SizedBox(height: 16),
                    PassphraseField(
                      controller: confirm,
                      enabled: !busy,
                      label: '再次输入加密口令',
                      validator: (value) =>
                          value != secret.text ? '两次加密口令不一致，请修改后重试' : null,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.t(
                          busy
                              ? '正在处理…'
                              : setup
                              ? '创建档案'
                              : '解锁档案',
                        ),
                      ),
                    ),
                  ),
                  if (!setup) ...[
                    TextButton.icon(
                      onPressed: busy || !widget.controller.canRestoreBackup
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                await restoreNativeBackup(
                                  context,
                                  widget.controller,
                                );
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      icon: const Icon(Icons.restore),
                      label: Text(context.t('从完整加密备份恢复到空档案')),
                    ),
                    if (!widget.controller.canRestoreBackup)
                      Text(
                        context.t('此设备已有资料时不整体替换。保留原档案，可在新设备的空档案恢复。'),
                        style: TextStyle(fontSize: 12),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => submit(device: true),
                      child: Text(context.t('使用本机保存的密钥解锁')),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              recovery = !recovery;
                              secret.clear();
                              failure = null;
                              form.currentState?.reset();
                            }),
                      child: Text(
                        context.t(recovery ? '改用加密口令' : '忘记口令？使用恢复密钥'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    context.t('内容在设备上加密后同步，解密密钥由你掌握。账号和必要的同步信息仍由服务端处理。'),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
