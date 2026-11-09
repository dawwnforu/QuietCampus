import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'settings.dart';
import 'theme.dart';
export 'theme.dart';
import 'auth_pages.dart';
import 'cloud.dart';
import 'controller.dart';
import 'reminders.dart';
import 'app_language.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerArchiveFontLicenses();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(
      const SetupApp(
        message: '请先连接自己的同步服务',
        detail: '复制 config.example.json 为 config.local.json，填入服务地址和客户端公开密钥，再运行：\n\nflutter run --dart-define-from-file=config.local.json\n\n管理密钥和解密密钥都不能填入此文件。',
      ),
    );
    return;
  }
  if (kReleaseMode && Uri.tryParse(url)?.scheme != 'https') {
    runApp(
      const SetupApp(
        message: '请配置 HTTPS 同步服务',
        detail: '正式构建需要连接受 TLS 保护的服务地址。',
      ),
    );
    return;
  }
  try {
    const secure = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    final sodium = await SodiumSumoInit.init();
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(secure),
      ),
    );
    final preview = Directory(
      p.join((await getTemporaryDirectory()).path, 'quiet-campus-preview'),
    );
    // This fixed app-owned cache only contains explicitly opened decrypted previews.
    if (await preview.exists()) await preview.delete(recursive: true);
    final reminders = Reminders();
    try {
      await reminders.initialize();
    } catch (_) {
      reminders.warning = '系统通知暂不可用，应用内待办仍可使用。';
    }
    final controller = ArchiveController(
      Supabase.instance.client,
      sodium,
      secure,
      reminders,
    );
    runApp(QuietCampusApp(controller: controller));
  } catch (_) {
    runApp(
      const SetupApp(
        message: '暂时无法启动档案',
        detail: '请检查服务地址、本机安全存储及原生组件是否可用，然后重新启动。已有档案不会被清除。',
      ),
    );
  }
}

class SetupApp extends StatelessWidget {
  const SetupApp({super.key, required this.message, required this.detail});
  final String message;
  final String detail;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: archiveTheme(),
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 24),
                Text(message, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                SelectableText(detail),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class QuietCampusApp extends StatefulWidget {
  const QuietCampusApp({super.key, required this.controller});
  final ArchiveController controller;
  @override
  State<QuietCampusApp> createState() => _QuietCampusAppState();
}

class _QuietCampusAppState extends State<QuietCampusApp>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _auth;
  final navigator = GlobalKey<NavigatorState>();
  bool wasUnlocked = false;
  Locale locale = const Locale('zh', 'CN');
  bool languageChosen = false;

  Future<void> loadLanguage() async {
    try {
      final value = await widget.controller.secure.read(
        key: 'quiet-campus.language',
      );
      if (mounted && !languageChosen && value == 'en') {
        setState(() => locale = const Locale('en'));
      }
    } catch (_) {
      // Optional preferences must not block opening an archive.
    }
  }

  void changeLanguage() {
    languageChosen = true;
    setState(
      () => locale = locale.languageCode == 'en'
          ? const Locale('zh', 'CN')
          : const Locale('en'),
    );
    unawaited(saveLanguage(locale.languageCode));
  }

  Future<void> saveLanguage(String language) async {
    try {
      await widget.controller.secure.write(
        key: 'quiet-campus.language',
        value: language,
      );
    } catch (_) {
      // Keep the in-session choice if preference storage is unavailable.
    }
  }

  void clearLockedRoutes() {
    final unlocked = widget.controller.unlocked;
    if (wasUnlocked && !unlocked) {
      navigator.currentState?.popUntil((route) => route.isFirst);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    wasUnlocked = unlocked;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    wasUnlocked = widget.controller.unlocked;
    unawaited(loadLanguage());
    widget.controller.addListener(clearLockedRoutes);
    _auth = widget.controller.client.auth.onAuthStateChange.listen((_) {
      unawaited(widget.controller.refreshSession());
    });
    unawaited(widget.controller.openAccount());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.controller.sync());
  }

  @override
  void dispose() {
    _auth?.cancel();
    widget.controller.removeListener(clearLockedRoutes);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ArchiveLanguageScope(
    onChange: changeLanguage,
    editionLabel:
        const String.fromEnvironment('APP_ENVIRONMENT') == 'production'
        ? '云同步版'
        : '云同步测试版',
    child: MaterialApp(
      title: locale.languageCode == 'en' ? 'Quiet Campus' : '静档',
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: archiveTheme(),
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      home: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          if (c.client.auth.currentUser == null) {
            return LoginPage(controller: c);
          }
          if (c.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!c.accountReady) {
            return Scaffold(
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ArchiveLanguageSwitch(),
                      Text(context.t(c.failure ?? '正在准备档案')),
                      AccountPanel(controller: c),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: c.openAccount,
                        child: Text(context.t('重新连接')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (!c.unlocked) return UnlockPage(controller: c);
          return ArchiveHome(
            controller: c,
            settingsBuilder: (_) => SettingsPage(controller: c),
            accountBuilder: (_) => AccountPanel(controller: c),
          );
        },
      ),
    ),
  );
}
