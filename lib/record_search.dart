import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

typedef MatchRange = ({int start, int end});
typedef _Unit = ({int code, int start, int end});
final _whitespace = RegExp(r'[\s\uFEFF]');

String _normalize(String value) =>
    unicode.nfkc(value).toLowerCase().replaceAll(_whitespace, '');

List<_Unit> _units(String text) {
  final result = <_Unit>[];
  var offset = 0;
  for (final grapheme in text.characters) {
    for (final code in _normalize(grapheme).runes) {
      result.add((code: code, start: offset, end: offset + grapheme.length));
    }
    offset += grapheme.length;
  }
  return result;
}

List<MatchRange> mergeMatchRanges(Iterable<MatchRange> ranges) {
  final sorted = ranges.toList()..sort((a, b) => a.start.compareTo(b.start));
  final merged = <MatchRange>[];
  for (final range in sorted) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final previous = merged.removeLast();
      merged.add((
        start: previous.start,
        end: range.end > previous.end ? range.end : previous.end,
      ));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

List<MatchRange>? _match(List<_Unit> units, List<int> wanted) {
  if (wanted.isEmpty) return [];
  final prefix = List<int>.filled(wanted.length, 0);
  for (var i = 1, j = 0; i < wanted.length; i++) {
    while (j > 0 && wanted[i] != wanted[j]) {
      j = prefix[j - 1];
    }
    if (wanted[i] == wanted[j]) j++;
    prefix[i] = j;
  }
  final hits = <MatchRange>[];
  final exact = List<bool>.filled(units.length, false);
  for (var i = 0, j = 0; i < units.length; i++) {
    while (j > 0 && units[i].code != wanted[j]) {
      j = prefix[j - 1];
    }
    if (units[i].code == wanted[j]) j++;
    if (j == wanted.length) {
      for (var k = i - j + 1; k <= i; k++) {
        exact[k] = true;
        hits.add((start: units[k].start, end: units[k].end));
      }
      j = prefix[j - 1];
    }
  }
  var part = <MatchRange>[];
  var next = 0;
  for (var i = 0; i < units.length; i++) {
    if (exact[i]) {
      next = 0;
      part = [];
      continue;
    }
    if (units[i].code == wanted[next]) {
      part.add((start: units[i].start, end: units[i].end));
      next++;
    }
    if (next == wanted.length) {
      hits.addAll(part);
      part = [];
      next = 0;
    }
  }
  return hits.isEmpty ? null : mergeMatchRanges(hits);
}

List<int> _query(String query) =>
    _normalize(query.replaceAll(RegExp(r'(^|\s)[#＃]'), '')).runes.toList();

List<MatchRange>? matchRanges(String text, String query) =>
    _match(_units(text), _query(query));

class EntryMatch {
  const EntryMatch(this.title, this.kind, this.body, this.tags, this.role);
  final List<MatchRange> title, kind, body, role;
  final List<List<MatchRange>> tags;
}

EntryMatch? searchRecordFields({
  required String title,
  required String kind,
  required String body,
  required List<String> tags,
  required String role,
  required String query,
}) {
  final wanted = _query(query);
  final fields = [title, kind, body, ...tags, role];
  if (wanted.isEmpty) {
    return EntryMatch([], [], [], [for (final _ in tags) []], []);
  }
  final parts = fields.map(_units).toList();
  final offsets = <int>[];
  final joined = <_Unit>[];
  var offset = 0;
  for (var i = 0; i < fields.length; i++) {
    offsets.add(offset);
    joined.addAll(
      parts[i].map(
        (u) => (code: u.code, start: offset + u.start, end: offset + u.end),
      ),
    );
    offset += fields[i].length + 1;
  }
  final all = _match(joined, wanted);
  if (all == null) return null;
  final ranges = <List<MatchRange>>[];
  for (var i = 0; i < fields.length; i++) {
    final start = offsets[i], end = start + fields[i].length;
    ranges.add(
      mergeMatchRanges([
        ...?_match(parts[i], wanted),
        for (final range in all)
          if (range.start < end && range.end > start)
            (
              start: range.start > start ? range.start - start : 0,
              end: range.end < end ? range.end - start : end - start,
            ),
      ]),
    );
  }
  return EntryMatch(
    ranges[0],
    ranges[1],
    ranges[2],
    ranges.sublist(3, ranges.length - 1),
    ranges.last,
  );
}

({String text, List<MatchRange> ranges}) searchExcerpt(
  String text,
  List<MatchRange> ranges, {
  int length = 90,
}) {
  final graphemes = text.characters.toList();
  final offsets = <int>[0];
  for (final part in graphemes) {
    offsets.add(offsets.last + part.length);
  }
  final hit = ranges.isEmpty ? 0 : ranges.first.start;
  final hitIndex = offsets.indexWhere((offset) => offset >= hit);
  final startIndex = hitIndex > 12 ? hitIndex - 12 : 0;
  final endIndex = (startIndex + length).clamp(0, graphemes.length);
  final start = offsets[startIndex], end = offsets[endIndex];
  final prefix = start == 0 ? '' : '…';
  return (
    text: '$prefix${text.substring(start, end)}${end < text.length ? '…' : ''}',
    ranges: [
      for (final range in ranges)
        if (range.start < end && range.end > start)
          (
            start: (range.start - start).clamp(0, end - start) + prefix.length,
            end: (range.end - start).clamp(0, end - start) + prefix.length,
          ),
    ],
  );
}

List<MatchRange> documentMatchRanges(
  List<dynamic> delta,
  List<MatchRange> ranges,
) {
  final result = <MatchRange>[];
  var textOffset = 0, documentOffset = 0;
  for (final operation in delta) {
    final insert = (operation as Map)['insert'];
    if (insert is String) {
      final end = textOffset + insert.length;
      for (final range in ranges) {
        if (range.start < end && range.end > textOffset) {
          result.add((
            start:
                documentOffset +
                (range.start - textOffset).clamp(0, insert.length),
            end:
                documentOffset +
                (range.end - textOffset).clamp(0, insert.length),
          ));
        }
      }
      textOffset = end;
      documentOffset += insert.length;
    } else {
      documentOffset++;
    }
  }
  return mergeMatchRanges(result);
}
