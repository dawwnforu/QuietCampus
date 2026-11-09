import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:sodium/sodium_sumo.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'backup_archive.dart';
import 'browser_archive_controller.dart';
import 'browser_snapshot_store.dart';
import 'demo_controller.dart';
import 'theme.dart';
import 'ui_helpers.dart';
import 'app_language.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerArchiveFontLicenses();
  runApp(const BrowserArchiveApp());
}

class BrowserArchiveApp extends StatefulWidget {
  const BrowserArchiveApp({super.key});
  @override
  State<BrowserArchiveApp> createState() => _BrowserArchiveAppState();
}

class _BrowserArchiveAppState extends State<BrowserArchiveApp> {
  BrowserSnapshotStore? store;
  BrowserArchiveController? archive;
  DemoController? demo;
  String? startupFailure;
  bool creatingVault = false;
  Locale locale = const Locale('zh', 'CN');

  @override
  void initState() {
    super.initState();
    try {
      if (web.window.localStorage.getItem('quiet-campus-language') == 'en') {
        locale = const Locale('en');
      }
    } catch (_) {
      /* Language preference is optional; archive storage is separate. */
    }
    if (Uri.base.queryParameters['demo'] == '1') {
      demo = DemoController();
    } else {
      open();
    }
  }

  void changeLanguage() {
    final next = locale.languageCode == 'en'
        ? const Locale('zh', 'CN')
        : const Locale('en');
    setState(() => locale = next);
    try {
      web.window.localStorage.setItem(
        'quiet-campus-language',
        next.languageCode,
      );
    } catch (_) {
      /* Keep the in-session choice even if preferences cannot be saved. */
    }
  }

  Future<void> open() async {
    try {
      final sodium = await SodiumSumoInit.init();
      store = await BrowserSnapshotStore.open();
      final c = BrowserArchiveController(store!, sodium);
      await c.load();
      if (!mounted) {
        c.dispose();
        store!.close();
        return;
      }
      setState(() => archive = c);
    } catch (_) {
      if (mounted) {
        setState(
          () => startupFailure = '浏览器加密或存储无法启动。原资料未清除，请勿清理站点数据；可重开页面再试。',
        );
      }
    }
  }

  @override
  void dispose() {
    archive?.dispose();
    demo?.dispose();
    store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: locale.languageCode == 'en'
        ? 'Quiet Campus · Local browser edition'
        : '静档 · 浏览器本地版',
    theme: archiveTheme().copyWith(splashFactory: InkRipple.splashFactory),
    locale: locale,
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    builder: (context, child) =>
        ArchiveLanguageScope(onChange: changeLanguage, child: child!),
    home: Builder(
      builder: (context) {
        if (demo case final DemoController c) {
          return Column(
            children: [
              Material(
                color: const Color(0xffe7f0eb),
                child: SafeArea(
                  bottom: false,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(context.t('合成示例体验 · 所有修改在刷新后重置，请勿填写私人内容')),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => demo = DemoController());
                          c.dispose();
                        },
                        child: Text(context.t('重置示例')),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: c,
                  builder: (_, _) =>
                      ArchiveHome(key: ObjectKey(c), controller: c),
                ),
              ),
            ],
          );
        }
        if (startupFailure != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t(startupFailure!)),
              ),
            ),
          );
        }
        final c = archive;
        if (c == null) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: context.t('正在打开本地加密存储'),
              ),
            ),
          );
        }
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => c.unlocked && !creatingVault
              ? ArchiveHome(
                  controller: c,
                  settingsBuilder: (_) => BrowserArchiveSettings(controller: c),
                )
              : BrowserArchiveGate(
                  controller: c,
                  onCreating: (value) {
                    if (mounted) setState(() => creatingVault = value);
                  },
                ),
        );
      },
    ),
  );
}

class BrowserArchiveGate extends StatefulWidget {
  const BrowserArchiveGate({
    super.key,
    required this.controller,
    required this.onCreating,
  });
  final BrowserArchiveController controller;
  final ValueChanged<bool> onCreating;
  @override
  State<BrowserArchiveGate> createState() => _BrowserArchiveGateState();
}

class _BrowserArchiveGateState extends State<BrowserArchiveGate> {
  final password = TextEditingController();
  final repeat = TextEditingController();
  bool visible = false;
  bool recovery = false;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final c = widget.controller;
    final creating = c.needsSetup;
    if (creating && password.text.runes.length < 12) {
      setState(() => error = '加密口令至少 12 个字符。输入已保留，可继续修改。');
      return;
    }
    if (creating && password.text != repeat.text) {
      setState(() => error = '两次口令不一致。输入已保留，请修改后重试。');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    if (creating) widget.onCreating(true);
    try {
      if (creating) {
        final key = await c.createVault(password.text);
        if (mounted) await showRecovery(context, key);
      } else {
        await c.unlock(password.text, recovery: recovery);
      }
    } catch (_) {
      if (mounted) setState(() => error = '未能打开档案，请核对口令或恢复密钥。输入和原资料均保留。');
    } finally {
      if (mounted) setState(() => busy = false);
      if (creating) widget.onCreating(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(actions: const [ArchiveLanguageSwitch()]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.t('给想法，留一个安静的位置。'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Text(
                context.t(
                  '浏览器本地加密版 · 不要求注册 · 不含云同步\n资料与当前浏览器、域名及端口绑定。清理站点数据、隐私模式或换设备可能丢失资料，请定期导出完整加密备份。',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                c.needsSetup ? context.t('建立自己的档案') : context.t('解锁已有档案'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (c.failure != null) ...[
                Text(
                  context.t(c.failure!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                OutlinedButton(
                  onPressed: busy ? null : c.load,
                  child: Text(context.t('重试读取，保留原资料')),
                ),
              ] else ...[
                TextField(
                  controller: password,
                  obscureText: !visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: recovery
                        ? context.t('恢复密钥')
                        : context.t('独立加密口令'),
                    helperText: c.needsSetup
                        ? context.t('至少 12 个字符；请勿重复使用邮箱密码')
                        : null,
                    suffixIcon: IconButton(
                      tooltip: visible ? context.t('隐藏口令') : context.t('显示口令'),
                      onPressed: () => setState(() => visible = !visible),
                      icon: Icon(
                        visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!busy) submit();
                  },
                ),
                if (c.needsSetup) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: repeat,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.t('再次输入加密口令'),
                    ),
                  ),
                ] else
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('使用恢复密钥')),
                    value: recovery,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => recovery = v ?? false),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      context.t(error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? context.t('正在处理…')
                        : c.needsSetup
                        ? context.t('建立本地档案')
                        : context.t('解锁'),
                  ),
                ),
                if (c.needsSetup)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => restoreBrowserBackup(context, c),
                    child: Text(context.t('从完整加密备份恢复')),
                  ),
              ],
              const SizedBox(height: 16),
              Text(context.t('所有解锁途径都丢失时无法找回。当前版本的小兔采用本机规则试讲，不调用在线 AI。')),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> restoreBrowserBackup(
  BuildContext context,
  BrowserArchiveController c,
) async {
  final expectedRevision = c.storageRevision;
  OpenedBackup? opened;
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty || !context.mounted) return;
    final file = files.single;
    if ((file.lengthSync() ?? 0) > BackupArchive.maxBytes) {
      throw const FormatException('请选择不超过 64 MiB 的完整加密备份');
    }
    final chunks = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (chunks.length + chunk.length > BackupArchive.maxBytes) {
        throw const FormatException('备份超过 64 MiB，原资料未改动');
      }
      chunks.add(chunk);
    }
    final archive = BackupArchive.decode(chunks.takeBytes());
    final password = TextEditingController();
    var recovery = false;
    var visible = false;
    bool? accepted;
    try {
      accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(context.t('验证备份，尚未导入')),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: password,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: recovery
                          ? context.t('此备份的恢复密钥')
                          : context.t('此备份的加密口令'),
                      suffixIcon: IconButton(
                        tooltip: visible
                            ? context.t('隐藏口令')
                            : context.t('显示口令'),
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('使用恢复密钥')),
                    value: recovery,
                    onChanged: (v) => setState(() => recovery = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t('取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t('验证并预览')),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      opened = await archive.unlock(
        c.sodium,
        password.text,
        recovery: recovery,
      );
    } finally {
      password.dispose();
    }
    if (!context.mounted) return;
    var backedUp = !c.hasStoredData;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.t('恢复预览')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      '已验证 {records} 个档案对象、{files} 份附件、{conflicts} 个待处理冲突。',
                      {
                        'records': opened!.entries.length,
                        'files': archive.files.length,
                        'conflicts': archive.conflicts.length,
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t(
                      '恢复会整体替换当前浏览器档案，不合并到云端。新资料使用备份自身的口令与恢复密钥。取消或失败不会覆盖原资料。',
                    ),
                  ),
                  if (c.hasStoredData)
                    BackupDownloadConfirmation(
                      download: () async {
                        await saveBytes(
                          'quiet-campus-before-restore.json',
                          await c.backup(),
                        );
                      },
                      onConfirmed: (value) => setState(() => backedUp = value),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('取消')),
            ),
            FilledButton(
              onPressed: backedUp ? () => Navigator.pop(context, true) : null,
              child: Text(context.t('确认整体恢复')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final imported = await c.restore(
      opened,
      expectedRevision: expectedRevision,
    );
    opened = null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported ? context.t('完整恢复已完成') : context.t('这份备份与当前档案相同，未重复导入'),
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  } finally {
    opened?.dispose();
  }
}

class BrowserArchiveSettings extends StatelessWidget {
  const BrowserArchiveSettings({super.key, required this.controller});
  final BrowserArchiveController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t('浏览器档案与备份')),
      actions: const [ArchiveLanguageSwitch()],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.t(
            '资料仅在此站点来源的浏览器中。完整加密档案暂限 64 MiB，单附件限 20 MiB；不是云盘或自动备份。换域名、端口、浏览器或设备前请先导出。下载成功提示不代表文件已安全另存，请核对下载目录。',
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(context.t('导出完整加密备份')),
          subtitle: Text(context.t('包含富文本、附件、材料、活动、标签与待处理版本')),
          onTap: () async {
            try {
              await saveBytes(
                'quiet-campus-backup-${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
                await controller.backup(),
              );
            } catch (e) {
              if (context.mounted) showFailure(context, e);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(context.t('从完整加密备份恢复')),
          subtitle: Text(context.t('先校验、预览并备份，再整体替换；不会静默覆盖')),
          onTap: () => restoreBrowserBackup(context, controller),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(context.t('锁定档案')),
          subtitle: Text(context.t('保留已保存资料，清除当前内存中的解锁能力')),
          onTap: () {
            Navigator.pop(context);
            controller.lock();
          },
        ),
        const SizedBox(height: 20),
        Text(
          context.t(
            '保留原资料的恢复路径：勿清理站点数据；先导出可读的完整备份。在另一个浏览器配置中验证备份可解锁后再考虑替换。旧版/损坏备份不自动升级或清空数据库。',
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '静档 / Quiet Campus',
          ),
          child: Text(context.t('第三方许可')),
        ),
      ],
    ),
  );
}
