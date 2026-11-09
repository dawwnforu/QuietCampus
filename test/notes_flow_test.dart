import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/app.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/notes_browser.dart';
import 'package:quiet_campus/record_export.dart';

class CapturedExports extends FilePickerPlatform {
  Uint8List? bytes;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.bytes = bytes;
    return Uri.file('C:/test-export/$fileName');
  }
}

Iterable<TextSpan> textLeaves(InlineSpan span) sync* {
  if (span is TextSpan) {
    if (span.text != null) yield span;
    for (final child in span.children ?? <InlineSpan>[]) {
      yield* textLeaves(child);
    }
  }
}

void main() {
  testWidgets(
    'native Flutter notes flow searches all batches, highlights rich text, edits and exports originals',
    (tester) async {
      tester.view.physicalSize = const Size(921, 871);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DemoController()
        ..entries = [
          for (var i = 0; i < 27; i++)
            Entry(
              id: 'entry-$i',
              title: '第 $i 篇随笔',
              kind: i == 26 ? 'project' : 'note',
              delta: i == 26
                  ? [
                      {'insert': '${'普通前文。' * 60}\n'},
                      {
                        'insert': '课堂之后再做项目。课堂项目',
                        'attributes': {'bold': true},
                      },
                      {'insert': '\n'},
                    ]
                  : [
                      {'insert': '普通正文\n'},
                    ],
              tags: ['大学生活'],
              createdAt: DateTime(2026, 10, 20).subtract(Duration(days: i)),
              updatedAt: DateTime(2026, 10, 20),
            ),
        ];
      final original = jsonEncode(c.entry('entry-26')!.toJson());
      final picker = CapturedExports(), previous = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previous);
      await tester.pumpWidget(ArchiveDemo(controller: c));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        3,
      );
      expect(find.text('27 篇记录 · 已显示 20 篇'), findsOneWidget);
      final date = DateTime.now();
      expect(
        find.bySemanticsLabel(
          RegExp('${date.year}年${date.month}月${date.day}日'),
        ),
        findsOneWidget,
      );
      final search = find.widgetWithText(TextField, '搜索标题、正文、标签、类型 · 支持模糊词');
      await tester.enterText(search, '课项');
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      expect(find.textContaining('课堂之后再做项目', findRichText: true), findsNothing);
      expect(jsonEncode(c.entry('entry-26')!.toJson()), original);
      await tester.tap(find.text('第 26 篇随笔'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetail), findsOneWidget);
      final rich = find.descendant(
        of: find.byType(ReadOnlyDocument),
        matching: find.byType(RichText),
      );
      final highlighted = tester
          .widgetList<RichText>(rich)
          .expand((w) => textLeaves(w.text))
          .where((s) => s.style?.background?.color.toARGB32() == 0xffffe69c)
          .toList();
      expect(highlighted.map((s) => s.text).join(), '课项课项');
      expect(
        highlighted.every((s) => s.style?.fontWeight == FontWeight.bold),
        isTrue,
      );
      expect(
        tester
            .widget<QuillEditor>(find.byType(QuillEditor))
            .controller
            .document
            .toDelta()
            .toJson(),
        c.entry('entry-26')!.delta,
      );
      await tester.tap(find.text('导出明文文本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择保存位置'));
      await tester.pumpAndSettle();
      expect(utf8.decode(picker.bytes!), recordText(c.entry('entry-26')!));
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '修改后的项目');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(c.entry('entry-26')!.title, '修改后的项目');
      expect(
        c.entry('entry-26')!.delta,
        (jsonDecode(original) as Map)['delta'],
      );
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      await tester.tap(find.text('导出全部随笔'));
      await tester.pumpAndSettle();
      expect(find.text('导出全部 27 篇随笔？'), findsOneWidget);
      await tester.tap(find.text('选择保存位置'));
      await tester.pumpAndSettle();
      final exported =
          (jsonDecode(utf8.decode(picker.bytes!)) as Map)['records'] as List;
      expect(exported.length, 27);
      expect(
        exported.where((e) => e['id'] == 'entry-26').single['delta'],
        c.entry('entry-26')!.delta,
      );
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('再显示 20 篇'),
        600,
        scrollable: scrollable,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('再显示 20 篇'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.text('27 篇记录 · 已显示 27 篇'), findsOneWidget);
      await tester.tap(find.text('新建标签'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '标签名称'), '#课后');
      await tester.tap(find.text('创建标签'));
      await tester.pumpAndSettle();
      expect(c.knownTags, contains('课后'));
      expect(find.text('27 篇记录 · 已显示 27 篇'), findsOneWidget);
      await tester.enterText(search, '项目');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1360, 900);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, '项目');
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowser), findsOneWidget);
      expect(tester.widget<TextField>(search).controller!.text, '项目');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
