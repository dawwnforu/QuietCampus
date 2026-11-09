import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'record_search.dart';

TextSpan highlightedSpan(
  String text,
  List<MatchRange> ranges, {
  TextStyle? style,
  GestureRecognizer? recognizer,
  int offset = 0,
}) {
  final children = <TextSpan>[];
  var cursor = 0;
  void append(int end, bool highlighted) {
    if (end <= cursor) return;
    children.add(
      TextSpan(
        text: text.substring(cursor, end),
        style: highlighted
            ? (style ?? const TextStyle()).copyWith(
                background: Paint()..color = const Color(0xffffe69c),
              )
            : style,
        recognizer: recognizer,
        mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
      ),
    );
    cursor = end;
  }

  for (final range in ranges) {
    if (range.end <= offset || range.start >= offset + text.length) continue;
    append((range.start - offset).clamp(cursor, text.length), false);
    append((range.end - offset).clamp(cursor, text.length), true);
  }
  append(text.length, false);
  return TextSpan(children: children, style: style);
}

class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text,
    this.ranges, {
    super.key,
    this.style,
    this.maxLines,
  });
  final String text;
  final List<MatchRange> ranges;
  final TextStyle? style;
  final int? maxLines;
  @override
  Widget build(BuildContext context) => Text.rich(
    highlightedSpan(text, ranges, style: style),
    maxLines: maxLines,
    overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
  );
}
