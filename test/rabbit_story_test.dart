import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/app.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/rabbit_avatar.dart';
import 'package:quiet_campus/rabbit_story.dart';
import 'package:quiet_campus/record_export.dart';

Entry note(
  String body, {
  String title = '一页随笔',
  String kind = 'note',
  String id = 'rabbit-note',
  List<String> tags = const [],
}) => Entry(
  id: id,
  title: title,
  kind: kind,
  tags: tags,
  delta: [
    {
      'insert': '$body\n',
      'attributes': {'bold': true},
    },
  ],
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

void main() {
  test('local rabbit wording uses profile name without changing rich text or exports', () {
    final entry = note('今天第一次在读书会上发言。下次想试试提前写下三个要点。');
    final before = jsonEncode(entry.toJson()),
        text = recordText(entry),
        backup = recordsJson([entry]);
    final story = rabbitStory(entry, name: ' 小禾 ');
    expect(story.text, startsWith('小禾第一次在读书会上发言啦'));
    expect(story.mood, RabbitMood.starry);
    expect(story.gesture, startsWith('【小兔'));
    expect(story.gesture, endsWith('】'));
    expect(rabbitStory(entry).text, startsWith('你第一次'));
    expect(jsonEncode(entry.toJson()), before);
    expect(recordText(entry), text);
    expect(recordsJson([entry]), backup);
    expect(backup.contains(story.gesture), isFalse);
  });

  test(
    'stage directions vary independently of artwork and stay stable per record',
    () {
      final scenes = [
        ('今天第一次在读书会上发言。', 'note', RabbitMood.starry),
        ('我很难过。', 'note', RabbitMood.gentle),
        ('我负责整理阅读区。', 'experience', RabbitMood.listening),
        ('目标：让闲置课本找到读者。', 'project', RabbitMood.thoughtful),
        ('今天随手写下一句话。', 'note', RabbitMood.listening),
      ];
      final allDirections = <String>{};
      for (final (body, kind, mood) in scenes) {
        final directions = <String>{};
        for (var i = 0; i < 4; i++) {
          final entry = note(body, kind: kind, id: 'note-$i');
          final before = jsonEncode(entry.toJson());
          final story = rabbitStory(entry);
          expect(story.mood, mood);
          expect(rabbitStory(entry).gesture, story.gesture);
          expect(rabbitStory(entry, name: '小禾').gesture, story.gesture);
          expect(jsonEncode(entry.toJson()), before);
          expect(recordsJson([entry]), isNot(contains(story.gesture)));
          directions.add(story.gesture);
        }
        expect(directions, hasLength(4));
        allDirections.addAll(directions);
      }
      expect(allDirections, hasLength(20));
    },
  );

  test('future, negation, quotes, other people and questions are not user accomplishments', () {
    for (final body in [
      '明天想第一次在读书会上发言。',
      '今天我没能在读书会上发言。',
      '朋友今天第一次在读书会上发言。',
      '“今天第一次在读书会上发言。”这是小说里的话。',
      '今天第一次在读书会上发言？',
      '如果今天第一次在读书会上发言，我会紧张。',
      '我负责明天的展示吗？',
    ]) {
      expect(
        rabbitStory(note(body)).mood,
        isNot(RabbitMood.starry),
        reason: body,
      );
    }
    expect(rabbitStory(note('我很难过，今天想歇一歇。')).mood, RabbitMood.gentle);
    expect(
      rabbitStory(note('目标：让闲置的课本找到下一位读者。', kind: 'project')).mood,
      RabbitMood.thoughtful,
    );
    expect(rabbitStory(note('我负责引导读者、整理儿童阅读区。')).text, contains('你记下了自己负责的事'));
    expect(
      rabbitStory(note('🧑‍🎓' * 100, title: '')).text.length,
      lessThan(80),
    );
  });

  testWidgets(
    'rabbit preview and arrow open original, while search and export keep using original',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry = note(
        '今天第一次在读书会上发言。下次想试试提前写下三个要点。',
        title: '有点紧张，也有一点进步',
        tags: ['大学生活'],
      );
      final c = DemoController()..entries = [entry];
      final original = jsonEncode(entry.toJson());
      await tester.pumpWidget(ArchiveDemo(controller: c));
      await tester.pumpAndSettle();
      expect(find.byType(RabbitAvatar), findsOneWidget);
      expect(find.text('小兔讲述'), findsNothing);
      expect(find.text('原文摘要'), findsNothing);
      final tagButton = find.ancestor(
        of: find.text('#大学生活', findRichText: true),
        matching: find.byType(TextButton),
      );
      final tagStyle = tester.widget<TextButton>(tagButton).style!;
      expect(tagStyle.foregroundColor!.resolve({}), const Color(0xff314d72));
      expect(tagStyle.textStyle!.resolve({})!.fontStyle, FontStyle.italic);
      expect(tagStyle.textStyle!.resolve({})!.fontSize, 12);
      await tester.tap(tagButton);
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      expect(
        tester.widgetList<FilterChip>(find.byType(FilterChip)).single.selected,
        isTrue,
      );
      expect(find.text(rabbitStory(entry).gesture), findsOneWidget);
      expect(
        find.textContaining('你第一次在读书会上发言啦', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('下次想试试提前写下', findRichText: true),
        findsNothing,
      );
      final search = find.widgetWithText(TextField, '搜索标题、正文、标签、类型 · 支持模糊词');
      await tester.enterText(search, '提前三要点');
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      expect(find.text('原文有匹配 · 点开查看'), findsNothing);
      await tester.tap(find.byTooltip('打开原文：有点紧张，也有一点进步'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryDetail), findsOneWidget);
      expect(find.text('写日记'), findsNothing);
      expect(
        find.textContaining('下次想试试提前写下', findRichText: true),
        findsWidgets,
      );
      expect(find.text(rabbitStory(entry).gesture), findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(RabbitAvatar), findsOneWidget);
      expect(
        find.textContaining('下次想试试提前写下', findRichText: true),
        findsNothing,
      );
      expect(jsonEncode(c.entry(entry.id)!.toJson()), original);
      tester.view.physicalSize = const Size(320, 720);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('all original rabbit expressions render with reduced motion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: Wrap(
              children: [
                for (final mood in RabbitMood.values) RabbitAvatar(mood: mood),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    for (final label in ['欣喜', '倾听', '思考', '陪伴']) {
      expect(find.bySemanticsLabel('小兔阿跃，$label'), findsOneWidget);
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
