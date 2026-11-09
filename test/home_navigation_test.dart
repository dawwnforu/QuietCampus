import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/archive_home.dart';
import 'package:quiet_campus/app.dart' show EntryDetail;
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/notes_browser.dart';
import 'package:quiet_campus/theme.dart';

void main() {
  testWidgets(
    'sidebar hides completely without losing reading or search; settings stays in account',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final archive = DemoController();
      await tester.pumpWidget(
        MaterialApp(
          theme: archiveTheme().copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          home: ArchiveHome(
            controller: archive,
            settingsBuilder: (_) => const Scaffold(body: Text('账号设置测试页')),
            accountBuilder: (_) => const Text('当前账号测试@example.invalid'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byTooltip('设置'), findsNothing);
      expect(find.text('当前账号测试@example.invalid'), findsNothing);
      final search = find.widgetWithText(TextField, '搜索标题、正文、标签、类型 · 支持模糊词');
      await tester.enterText(search, '读书');
      await tester.pumpAndSettle();
      await tester.tap(find.text('有点紧张，也有一点进步').first);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetail), findsOneWidget);
      final before = tester.getTopLeft(find.byType(NotesBrowser)).dx;
      await tester.tap(find.byTooltip('收起导航'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.getTopLeft(find.byType(NotesBrowser)).dx, lessThan(before));
      expect(tester.widget<TextField>(search).controller!.text, '读书');
      expect(find.byType(EntryDetail), findsOneWidget);
      expect(find.byTooltip('新记录'), findsOneWidget);
      await tester.tap(find.byTooltip('展开导航'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, '读书');
      await tester.tap(find.text('活动').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('设置'), findsNothing);
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('设置'), findsOneWidget);
      expect(find.text('当前账号测试@example.invalid'), findsOneWidget);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      expect(find.text('账号设置测试页'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收起导航'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);
      expect(find.text('当前账号测试@example.invalid'), findsOneWidget);
      await tester.tap(find.text('随笔').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('设置'), findsNothing);
      expect(find.text('当前账号测试@example.invalid'), findsNothing);
      tester.view.physicalSize = const Size(1360, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byTooltip('展开导航'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      archive.dispose();
    },
  );
}
