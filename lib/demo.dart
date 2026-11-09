import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'app.dart';
import 'demo_controller.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerArchiveFontLicenses();
  runApp(ArchiveDemo(controller: DemoController()));
}

class ArchiveDemo extends StatelessWidget {
  const ArchiveDemo({super.key, required this.controller});
  final DemoController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '静档 · 可操作演示',
    theme: archiveTheme().copyWith(splashFactory: InkRipple.splashFactory),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    home: ListenableBuilder(
      listenable: controller,
      builder: (_, _) => ArchiveHome(controller: controller),
    ),
  );
}
