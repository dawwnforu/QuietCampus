import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/app_language.dart';
import 'package:quiet_campus/archive_home.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/editor.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/notes_browser.dart';
import 'package:quiet_campus/rabbit_story.dart';
import 'package:quiet_campus/record_export.dart';
import 'package:quiet_campus/search_highlight.dart';
import 'package:quiet_campus/theme.dart';

Widget localized(ValueNotifier<Locale> locale, Widget home) =>
    ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, value, _) => MaterialApp(
        theme: archiveTheme(),
        locale: value,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        builder: (context, child) => ArchiveLanguageScope(
          onChange: () => locale.value = context.english
              ? const Locale('zh', 'CN')
              : const Locale('en'),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  testWidgets('UI placeholders never reinterpret or translate user values', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      localized(
        locale,
        Builder(
          builder: (context) => Text(
            context.t('打开原文：{title}', {'title': '保存 {count}', 'count': 7}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open original: 保存 {count}'), findsOneWidget);
    locale.value = const Locale('zh', 'CN');
    await tester.pumpAndSettle();
    expect(find.text('打开原文：保存 {count}'), findsOneWidget);
  });

  test('localized type search returns offsets for the displayed text and keeps source intact', () {
    final entry = Entry(
      id: 'language-test',
      kind: 'project',
      title: 'Plan A',
      delta: const [
        {
          'insert': '中文 road map road map\n',
          'attributes': {'bold': true},
        },
      ],
      tags: const ['保存', 'project tag'],
      createdAt: DateTime(2026, 10, 26),
      updatedAt: DateTime(2026, 10, 26),
    );
    final before = recordsJson([entry]);
    final english = entry.search('project', displayKind: 'Project')!;
    expect(english.kind, [(start: 0, end: 7)]);
    expect(entry.search('项目', displayKind: 'Project')!.kind, isEmpty);
    expect(
      entry.search('Plan A project 中文', displayKind: 'Project'),
      isNotNull,
    );
    expect(entry.search('roadmap', displayKind: 'Project')!.body.length, 4);
    final story = rabbitStory(entry, english: true);
    expect(story.text, contains('project page'));
    expect(story.gesture, startsWith('【The rabbit'));
    expect(recordsJson([entry]), before);
    expect(jsonEncode(entry.delta), isNot(contains('background')));
  });

  testWidgets(
    'locale changes keep the mounted editor, rich text, tags and pending title',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final archive = DemoController();
      final locale = ValueNotifier(const Locale('zh', 'CN'));
      addTearDown(archive.dispose);
      addTearDown(locale.dispose);
      final entry = archive.entries.firstWhere((e) => e.kind == 'note');
      final untouched = recordsJson(
        archive.entries.where((e) => e.id != entry.id),
      );
      Entry? saved;
      await tester.pumpWidget(
        localized(
          locale,
          Scaffold(
            body: EntryEditor(
              controller: archive,
              entry: entry,
              onFinished: (e) => saved = e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<EntryEditorState>(find.byType(EntryEditor));
      state.title.text = '保存 Save {count}';
      state.quill.formatText(0, 2, Attribute.bold);
      state.tags.text = '#未完成输入';
      final delta = jsonEncode(state.quill.document.toDelta().toJson());
      final tags = [...state.selectedTags];
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      expect(
        tester.state<EntryEditorState>(find.byType(EntryEditor)),
        same(state),
      );
      expect(state.title.text, '保存 Save {count}');
      expect(state.tags.text, '#未完成输入');
      expect(state.selectedTags, tags);
      expect(jsonEncode(state.quill.document.toDelta().toJson()), delta);
      expect(find.text('Save'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Title (optional)'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.title, '保存 Save {count}');
      expect(jsonEncode(saved!.delta), delta);
      expect(saved!.tags, contains('未完成输入'));
      expect(
        recordsJson(archive.entries.where((e) => e.id != entry.id)),
        untouched,
      );
    },
  );

  testWidgets(
    'English search, translated highlights and narrow navigation work without resetting query',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final archive = DemoController();
      final locale = ValueNotifier(const Locale('en'));
      addTearDown(archive.dispose);
      addTearDown(locale.dispose);
      final before = recordsJson(archive.entries);
      await tester.pumpWidget(
        localized(locale, ArchiveHome(controller: archive)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'project');
      await tester.pumpAndSettle();
      expect(find.byType(NotesBrowser), findsOneWidget);
      final labels = tester
          .widgetList<HighlightedText>(find.byType(HighlightedText))
          .where((w) => w.text == 'Project');
      expect(labels, isNotEmpty);
      expect(labels.first.ranges, [(start: 0, end: 7)]);
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'project',
      );
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(find.text('Material library'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(recordsJson(archive.entries), before);
    },
  );
}
