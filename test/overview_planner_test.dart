import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/calendar_export.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/overview.dart';
import 'package:quiet_campus/planner.dart';

Entry entry(
  String id,
  String kind,
  DateTime time, {
  String body = '你 好\n',
  DateTime? start,
  DateTime? end,
}) => Entry(
  id: id,
  title: id,
  kind: kind,
  delta: [
    {'insert': body},
  ],
  createdAt: time,
  updatedAt: time,
  startsAt: start,
  endsAt: end,
);

void main() {
  test('overview excludes profile and schedules, counts body and creation dates once', () {
    final today = DateTime(2026, 10, 20);
    final note = entry('n', 'note', today);
    final project = entry(
      'p',
      'project',
      today.add(const Duration(days: 1)),
      body: '项目ABC!',
    );
    final stats = ArchiveStats([
      note,
      project,
      entry('profile', 'profile', today),
      entry('event', 'activity', today),
    ]);
    expect(stats.records, 2);
    expect(stats.projects, 1);
    expect(stats.characters, 8);
    expect(stats.days.length, 2);
    expect(stats.days[today], 1);
    final legacy = note.toJson()
      ..remove('startsAt')
      ..remove('endsAt')
      ..remove('profile')
      ..remove('reminderTarget');
    expect(Entry.fromJson(note.id, legacy).reminderTarget, 'app');
  });
  test('calendar includes overnight events but excludes the exact end day and private records', () {
    final date = DateTime(2026, 10, 20);
    final event = entry(
      'overnight',
      'activity',
      date,
      start: DateTime(2026, 10, 20, 23),
      end: DateTime(2026, 10, 22),
    );
    expect(scheduleOn([event], date).length, 1);
    expect(scheduleOn([event], DateTime(2026, 10, 21)).length, 1);
    expect(scheduleOn([event], DateTime(2026, 10, 22)), isEmpty);
    expect(
      scheduleOn([entry('note', 'note', date, start: date)], date),
      isEmpty,
    );
    final restored = Entry.fromJson(event.id, event.toJson());
    expect(restored.startsAt, event.startsAt);
    expect(restored.endsAt, event.endsAt);
  });
  test('calendar export minimizes fields, escapes newlines, folds UTF-8 and uses UTC', () {
    final event = Entry(
      id: 'test',
      title: '${'私密中文' * 30}\nBEGIN:VEVENT',
      delta: const [
        {'insert': '绝不能导出的正文\n'},
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      startsAt: DateTime.utc(2026, 10, 20, 10),
      reminder: DateTime.utc(2026, 10, 20, 9, 45),
    );
    final hidden = calendarFile(event, includeTitle: false);
    expect(hidden, contains('SUMMARY:静档日程'));
    expect(hidden, isNot(contains('私密')));
    expect(hidden, isNot(contains('绝不能导出的正文')));
    expect(hidden, contains('DTSTART:20261020T100000Z'));
    expect(hidden, contains('BEGIN:VALARM'));
    final named = calendarFile(event, includeTitle: true);
    expect(
      named.split('\r\n').where((line) => line == 'BEGIN:VEVENT').length,
      1,
    );
    expect(named.replaceAll('\r\n ', ''), contains(r'\nBEGIN:VEVENT'));
    for (final line in named.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
  });
  testWidgets(
    'mobile overview, centered add, profile edit and calendar timeline work',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = DemoController();
      await tester.pumpWidget(ArchiveDemo(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('随笔'), findsWidgets);
      final plus = tester.getCenter(find.byTooltip('新记录'));
      expect(plus.dx, closeTo(195, 1));
      await tester.tap(find.text('档案'));
      await tester.pumpAndSettle();
      expect(find.text('留下记录'), findsOneWidget);
      expect(find.text('写下字数'), findsOneWidget);
      expect(find.byType(ArchiveOverview), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('编辑个人资料'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '小林');
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      expect(
        controller.entry(ArchiveOverview.profileId)?.profile['name'],
        '小林',
      );
      expect(find.text('小林'), findsOneWidget);
      await tester.tap(find.text('活动'));
      await tester.pumpAndSettle();
      expect(find.byType(SchedulePlanner), findsOneWidget);
      expect(find.textContaining('时间轴'), findsOneWidget);
      await tester.tap(find.text('添加日程'));
      await tester.pumpAndSettle();
      expect(find.text('开始时间'), findsOneWidget);
      expect(find.text('系统日历'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '明天的计划');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('同时提供日程名称'), findsOneWidget);
      await tester.tap(find.text('先留在静档'));
      await tester.pumpAndSettle();
      expect(find.text('明天的计划'), findsOneWidget);
      expect(controller.entries.first.startsAt, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
