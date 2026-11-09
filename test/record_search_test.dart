import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/record_export.dart';
import 'package:quiet_campus/record_search.dart';

Entry record(
  String id, {
  String title = '随笔',
  String kind = 'note',
  String body = '正文\n',
  List<String> tags = const [],
}) => Entry(
  id: id,
  title: title,
  kind: kind,
  delta: [
    {'insert': body},
  ],
  tags: tags,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

List<String> segments(String text, List<MatchRange>? ranges) => [
  for (final range in ranges ?? <MatchRange>[])
    text.substring(range.start, range.end),
];

void main() {
  test(
    'all exact and separate sequential occurrences share highlight ranges',
    () {
      const text = '校园 校里的园 校园 校里的园';
      expect(segments(text, matchRanges(text, '校园')), [
        '校园',
        '校',
        '园',
        '校园',
        '校',
        '园',
      ]);
      expect(matchRanges('aaaa', 'aa'), [(start: 0, end: 4)]);
      expect(matchRanges('园校', '校园'), isNull);
      expect(matchRanges('大学', '大穴'), isNull);
      expect(matchRanges('任何文字', ' \n '), isEmpty);
    },
  );

  test('normalization maps compatibility characters and whole graphemes back to originals', () {
    const text = 'ＡＢＣ ① ﬃ';
    expect(segments(text, matchRanges(text, 'abc1ffi')), ['ＡＢＣ', '①', 'ﬃ']);
    const accents = 'e\u0301 😀 👨‍👩‍👧';
    expect(segments(accents, matchRanges(accents, 'É😀')), ['e\u0301', '😀']);
    expect(segments(accents, matchRanges(accents, '👨‍👩‍👧')), ['👨‍👩‍👧']);
  });

  test('title, kind, content and tags match together, including repeated field hits', () {
    final entry = record(
      'a',
      title: '制作',
      kind: 'project',
      body: '校园导览\n',
      tags: ['校园'],
    );
    final hit = entry.search('作项目校园')!;
    expect(segments(entry.title, hit.title), ['作']);
    expect(segments(entry.kindLabel, hit.kind), ['项目']);
    expect(segments(entry.plainText, hit.body), ['校园']);
    expect(entry.search('项目')!.kind, isNotEmpty);
    expect(entry.search('#校园')!.tags.single, isNotEmpty);
    expect(entry.search('读书'), isNull);
    expect(entry.search('')!.body, isEmpty);
  });

  test('late body excerpt uses grapheme boundaries and document ranges account for embeds', () {
    final body = '${'普通👨‍👩‍👧文字。' * 40}课堂之后再做项目。课堂项目\n';
    final hit = matchRanges(body, '课项')!;
    final excerpt = searchExcerpt(body, hit);
    expect(excerpt.text.startsWith('…'), isTrue);
    expect(excerpt.text, contains('课堂之后再做项目'));
    expect(segments(excerpt.text, excerpt.ranges), ['课', '项', '课', '项']);
    expect(excerpt.text.contains('\uFFFD'), isFalse);
    expect(
      documentMatchRanges(
        [
          {'insert': '先'},
          {
            'insert': {'image': 'image-id'},
          },
          {'insert': '后关键词\n'},
        ],
        [(start: 2, end: 5)],
      ),
      [(start: 3, end: 6)],
    );
  });

  test(
    'search and exports retain original rich Delta and include all notes only',
    () {
      final entries = [
        for (var i = 0; i < 27; i++)
          record('$i', kind: i == 26 ? 'project' : 'note'),
      ];
      final rich = Entry.fromJson('rich', {
        ...entries.first.toJson(),
        'title': 'Ａ项目',
        'delta': [
          {
            'insert': '课堂',
            'attributes': {'bold': true},
          },
          {'insert': '项目\n'},
        ],
      });
      final original = jsonEncode(rich.toJson());
      rich.search('课项');
      rich.search('项目');
      final exported = jsonDecode(
        recordsJson([
          ...entries,
          rich,
          record('catalog', kind: 'tag_catalog'),
          record('profile', kind: 'profile'),
        ]),
      ) as Map;
      expect((exported['records'] as List).length, 28);
      expect((exported['records'] as List).last['delta'], rich.delta);
      expect(recordText(rich), contains('课堂项目'));
      expect(recordText(rich), isNot(contains('<mark>')));
      expect(jsonEncode(rich.toJson()), original);
    },
  );

  test('measure full client search on 1000 synthetic entries without real archive data', () {
    final entries = [
      for (var i = 0; i < 1000; i++)
        record('$i', body: '${'普通记录。' * 50}课堂之后再做项目。\n'),
    ];
    final clock = Stopwatch()..start();
    expect(entries.where((e) => e.matches('课项')).length, 1000);
    clock.stop();
    // Synthetic timing is diagnostic, not a device performance guarantee.
    debugPrint(
      'synthetic-search: 1000 entries, ${clock.elapsedMilliseconds} ms',
    );
  });
}
