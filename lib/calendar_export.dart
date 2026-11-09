import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'ui_helpers.dart';
import 'app_language.dart';

String calendarStamp(DateTime date) =>
    '${date.toUtc().toIso8601String().split('.').first.replaceAll(RegExp('[-:]'), '')}Z';
String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

String calendarFile(Entry entry, {required bool includeTitle, DateTime? now}) {
  final start = entry.scheduleDate;
  if (start == null) throw const FormatException('请先设置日程时间');
  final end = entry.endsAt ?? start.add(const Duration(hours: 1));
  if (!end.isAfter(start)) throw const FormatException('结束时间需要晚于开始时间');
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Quiet Campus//Private Schedule//ZH',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:${entry.id.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '')}@quiet-campus.local',
    'DTSTAMP:${calendarStamp(now ?? DateTime.now())}',
    'DTSTART:${calendarStamp(start)}',
    'DTEND:${calendarStamp(end)}',
    'SUMMARY:${_escape(includeTitle && entry.title.isNotEmpty ? entry.title : '静档日程')}',
    if (entry.reminder != null) ...[
      'BEGIN:VALARM',
      'TRIGGER;VALUE=DATE-TIME:${calendarStamp(entry.reminder!)}',
      'ACTION:DISPLAY',
      'DESCRIPTION:日程提醒',
      'END:VALARM',
    ],
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  // RFC 5545 folds lines by UTF-8 octets without splitting a code point.
  return '${lines.map((line) {
    var length = 0;
    final folded = StringBuffer();
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (length + size > 75) {
        folded.write('\r\n ');
        length = 1;
      }
      folded.write(character);
      length += size;
    }
    return folded.toString();
  }).join('\r\n')}\r\n';
}

Future<void> exportToCalendar(BuildContext context, Entry entry) async {
  var includeTitle = false;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.t('添加到系统日历')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                '仅提供时间和提醒，名称默认为“静档日程”。日记正文、标签、个人资料和附件不会导出。系统日历可能同步到你使用的日历云服务。',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: includeTitle,
              title: Text(context.t('同时提供日程名称')),
              onChanged: (value) =>
                  setState(() => includeTitle = value ?? false),
            ),
            if (kIsWeb ||
                ![
                  TargetPlatform.iOS,
                  TargetPlatform.android,
                ].contains(defaultTargetPlatform))
              const Text(
                '当前设备会下载日历文件（.ics），可自行导入日历。',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('先留在静档')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('继续')),
          ),
        ],
      ),
    ),
  );
  if (proceed != true || !context.mounted) return;
  try {
    final start = entry.scheduleDate;
    if (start == null) throw const FormatException('请先设置日程时间');
    final end = entry.endsAt ?? start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) throw const FormatException('结束时间需要晚于开始时间');
    if (kIsWeb ||
        ![
          TargetPlatform.iOS,
          TargetPlatform.android,
        ].contains(defaultTargetPlatform)) {
      await saveBytes(
        'quiet-campus-event.ics',
        Uint8List.fromList(
          utf8.encode(calendarFile(entry, includeTitle: includeTitle)),
        ),
      );
    } else {
      final opened = await const MethodChannel('cn.quietcampus/calendar')
          .invokeMethod<bool>('addEvent', {
            'title': includeTitle && entry.title.isNotEmpty
                ? entry.title
                : '静档日程',
            'start': start.millisecondsSinceEpoch,
            'end': end.millisecondsSinceEpoch,
            'reminder': entry.reminder?.millisecondsSinceEpoch,
          });
      if (opened == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已打开系统日历，请确认保存和闹钟设置；系统日历中的副本需单独修改或删除。')),
        );
      }
    }
  } on PlatformException catch (error) {
    if (context.mounted) {
      showFailure(context, StateError(error.message ?? '系统日历暂不可用'));
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}
