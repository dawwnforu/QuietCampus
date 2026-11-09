import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/app.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/editor.dart';
import 'package:quiet_campus/markdown_typing.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/notes_browser.dart';

QuillController typed(String text, {Map<String, dynamic>? attributes}) =>
    QuillController(
      document: Document.fromJson([
        {'insert': text},
        {'insert': '\n', 'attributes': ?attributes},
      ]),
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  test(
    'Markdown block shortcuts preserve content and survive Delta round trips',
    () {
      for (final (marker, attribute) in [
        ('# ', Attribute.h1),
        ('## ', Attribute.h2),
        ('### ', Attribute.h3),
        ('- ', Attribute.ul),
        ('1. ', Attribute.ol),
        ('> ', Attribute.blockQuote),
        ('[ ] ', Attribute.unchecked),
        ('[x] ', Attribute.checked),
        ('``` ', Attribute.codeBlock),
      ]) {
        final controller = typed(marker);
        expect(applyMarkdownTyping(controller), isTrue, reason: marker);
        expect(controller.document.toPlainText(), '\n');
        expect(
          controller.document.toDelta().toJson().last['attributes'],
          containsPair(attribute.key, attribute.value),
        );
        controller.replaceText(
          0,
          0,
          '中文内容',
          const TextSelection.collapsed(offset: 4),
        );
        final delta = controller.document.toDelta().toJson();
        expect(Document.fromJson(delta).toDelta().toJson(), delta);
        expect(controller.document.toPlainText(), '中文内容\n');
        controller.dispose();
      }
    },
  );

  test('inline formatting, escapes, code, IME and pending bold are handled without losing text', () {
    for (final (text, plain, attribute) in [
      ('**勇敢发言**', '勇敢发言', Attribute.bold),
      ('__继续尝试__', '继续尝试', Attribute.bold),
      ('*慢慢来*', '慢慢来', Attribute.italic),
      ('~~旧计划~~', '旧计划', Attribute.strikeThrough),
      ('`print()`', 'print()', Attribute.inlineCode),
    ]) {
      final controller = typed(text);
      expect(applyMarkdownTyping(controller), isTrue, reason: text);
      expect(controller.document.toPlainText(), '$plain\n');
      expect(
        controller.document.toDelta().toJson().first['attributes'],
        containsPair(attribute.key, attribute.value),
      );
      controller.dispose();
    }
    for (final text in [r'\**保留符号**', '**尚未结束*', '普通 # ', '## 标题内容']) {
      final controller = typed(text);
      final before = jsonEncode(controller.document.toDelta().toJson());
      expect(applyMarkdownTyping(controller), isFalse, reason: text);
      expect(jsonEncode(controller.document.toDelta().toJson()), before);
      controller.dispose();
    }
    final composing = typed('# ');
    expect(applyMarkdownTyping(composing, composing: true), isFalse);
    expect(composing.document.toPlainText(), '# \n');
    composing.dispose();
    final code = typed('**原样代码**', attributes: {'code-block': true});
    expect(applyMarkdownTyping(code), isFalse);
    code.dispose();
  });

  testWidgets(
    'editing stays beside the list, keeps a draft across layouts and guards navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final archive = DemoController();
      final entry = archive.entries.firstWhere((e) => e.kind == 'note');
      final before = jsonEncode(entry.toJson());
      final delta = jsonEncode(entry.delta);
      await tester.pumpWidget(ArchiveDemo(controller: archive));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.title).first);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetail), findsOneWidget);
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowser), findsOneWidget);
      expect(find.byType(EntryEditor), findsOneWidget);
      expect(
        tester.widget<EntryEditor>(find.byType(EntryEditor)).onFinished,
        isNotNull,
      );
      final state = tester.state<EntryEditorState>(find.byType(EntryEditor));
      expect(jsonEncode(state.quill.document.toDelta().toJson()), delta);
      expect(find.byType(QuillSimpleToolbar), findsNothing);
      await tester.enterText(find.byKey(const Key('document-title')), '文档式随笔');
      expect(jsonEncode(archive.entry(entry.id)!.toJson()), before);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(
        tester.state<EntryEditorState>(find.byType(EntryEditor)),
        same(state),
      );
      expect(find.text('文档式随笔'), findsOneWidget);
      tester.view.physicalSize = const Size(1360, 900);
      await tester.pumpAndSettle();
      await tester.tap(find.text('活动').last);
      await tester.pumpAndSettle();
      expect(find.text('放弃尚未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('继续记录'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditor), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditor), findsNothing);
      expect(find.byType(EntryDetail), findsOneWidget);
      expect(archive.entry(entry.id)!.title, '文档式随笔');
      expect(jsonEncode(archive.entry(entry.id)!.delta), delta);
      expect(archive.entry(entry.id)!.tags, entry.tags);
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-title')),
        '不保留这次修改',
      );
      await tester.tap(find.byTooltip('结束编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(archive.entry(entry.id)!.title, '文档式随笔');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      archive.dispose();
    },
  );

  testWidgets(
    'virtual keyboard Markdown input formats and saves the actual rich document',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final archive = DemoController()..entries = [];
      await tester.pumpWidget(ArchiveDemo(controller: archive));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('写日记'));
      await tester.pumpAndSettle();
      final state = tester.state<EntryEditorState>(find.byType(EntryEditor));
      await tester.ensureVisible(find.byKey(const Key('document-body')));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        final body = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^正文')));
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          body.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(state.documentFocus.hasFocus, true);
      } finally {
        semantics.dispose();
      }
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '# \n',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.quill.document.toPlainText(), '# \n');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '# \n',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.quill.document.toPlainText(), '\n');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '今天的收获\n',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pumpAndSettle();
      final editingSemantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        final body = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^正文')));
        tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
          body.id,
          SemanticsAction.setText,
          '今天的收获，再看一遍\n',
        );
        await tester.pumpAndSettle();
        expect(state.quill.document.toPlainText(), '今天的收获，再看一遍\n');
      } finally {
        editingSemantics.dispose();
      }
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = archive.entries.single;
      expect(saved.plainText.trim(), '今天的收获，再看一遍');
      expect(saved.delta.last['attributes'], containsPair('header', 1));
      expect(Entry.fromJson(saved.id, saved.toJson()).delta, saved.delta);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      archive.dispose();
    },
  );

  testWidgets(
    'undo restores a legacy literal without immediately formatting it',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final entry = Entry(
        id: 'literal',
        title: '保留原文符号',
        delta: const [
          {'insert': '**原文符号**\n'},
        ],
        createdAt: now,
        updatedAt: now,
      );
      final archive = DemoController()..entries = [entry];
      await tester.pumpWidget(ArchiveDemo(controller: archive));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.title).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      final editor = tester.state<EntryEditorState>(find.byType(EntryEditor));
      expect(editor.quill.document.toDelta().toJson(), entry.delta);
      final at = editor.quill.document.length - 2;
      editor.quill.replaceText(at, 1, '', TextSelection.collapsed(offset: at));
      await tester.pumpAndSettle();
      editor.quill.undo();
      await tester.pumpAndSettle();
      expect(editor.quill.document.toDelta().toJson(), entry.delta);
      editor.quill.redo();
      await tester.pumpAndSettle();
      expect(editor.quill.document.toPlainText(), '**原文符号*\n');
      expect(archive.entry(entry.id)!.delta, entry.delta);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      archive.dispose();
    },
  );
}
