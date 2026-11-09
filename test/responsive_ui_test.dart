import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiet_campus/app.dart';
import 'package:quiet_campus/controller.dart';
import 'package:quiet_campus/main.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/reminders.dart';

// This fixture exercises presentation only; crypto has its own real-library checks.
class _UnusedCrypto implements SodiumSumo {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('UI test must not call crypto');
}

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('UI test must not call the network');
}

void main() {
  testWidgets(
    'desktop split view, mobile navigation and editor fit their screens',
    (tester) async {
      final writePreview = Platform.environment['WRITE_UI_PREVIEW'] == '1';
      if (writePreview && Platform.isWindows) {
        await tester.runAsync(() async {
          for (final font in [
            ('QuietSans', 'NotoSansSC-Regular.otf'),
            ('QuietDisplay', 'LXGWWenKaiLite-Regular.ttf'),
          ]) {
            await (FontLoader(font.$1)..addFont(
                  File('assets/fonts/${font.$2}')
                      .readAsBytes()
                      .then(ByteData.sublistView),
                ))
                .load();
          }
          final font = File(r'C:\Windows\Fonts\msyh.ttc');
          if (await font.exists()) {
            final loader = FontLoader('Roboto')
              ..addFont(
                font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              );
            await loader.load();
          }
          final icons = File(
            '.tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          );
          if (await icons.exists()) {
            await (FontLoader('MaterialIcons')..addFont(
                  icons.readAsBytes().then(
                    (bytes) => ByteData.sublistView(bytes),
                  ),
                ))
                .load();
          }
        });
      }
      final client = _UnusedClient();
      final c = ArchiveController(
        client,
        _UnusedCrypto(),
        const FlutterSecureStorage(),
        Reminders(),
      );
      c.syncStatus = '示例资料 · 界面预览';
      c.entries = [
        Entry(
          id: 'note',
          title: '有点紧张，也有一点进步',
          tags: ['大学生活', '反思'],
          delta: const [
            {'insert': '今天第一次在读书会上发言。\n刚开始声音很小，后来慢慢说出了自己的想法。\n'},
            {
              'insert': '下次想试试提前写下三个要点。',
              'attributes': {'bold': true},
            },
            {'insert': '\n'},
          ],
          createdAt: DateTime(2026, 10, 20, 18, 30),
          updatedAt: DateTime(2026, 10, 20, 18, 30),
        ),
        Entry(
          id: 'event',
          title: '社区图书馆志愿服务',
          kind: 'activity',
          status: ActivityStatus.completed,
          tags: ['志愿', '经历'],
          role: '引导读者、整理儿童阅读区',
          delta: const [
            {'insert': '第一次独立负责阅读区，遇到了很有耐心的小读者。\n'},
          ],
          attachments: const [
            Attachment(id: 'proof', name: '志愿服务证明.pdf', size: 2048),
          ],
          createdAt: DateTime(2026, 10, 18),
          updatedAt: DateTime(2026, 10, 18),
        ),
      ];
      final boundary = GlobalKey();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1360, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> capture(String name) async {
        if (!writePreview) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('.tooling/ui-preview');
            await folder.create(recursive: true);
            await File('${folder.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: archiveTheme().copyWith(
              platform: TargetPlatform.windows,
              splashFactory: InkRipple.splashFactory,
            ),
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            home: ArchiveHome(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.tap(find.text('有点紧张，也有一点进步').first);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetail), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (writePreview) {
        await tester.enterText(
          find.widgetWithText(TextField, '搜索标题、正文、标签、类型 · 支持模糊词'),
          '读书发言',
        );
        await tester.pumpAndSettle();
      }
      await capture('windows');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('mobile');
      await tester.tap(find.byTooltip('新记录'));
      await tester.pumpAndSettle();
      expect(find.text('写日记'), findsOneWidget);
      expect(find.text('留经历'), findsOneWidget);
      expect(find.text('存项目'), findsOneWidget);
      await tester.tap(find.text('写日记'));
      await tester.pumpAndSettle();
      expect(find.text('写日记'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('editor');
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
