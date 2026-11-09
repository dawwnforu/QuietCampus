import 'package:flutter/material.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Called only after local text input, never when loading or exporting a record.
bool applyMarkdownTyping(QuillController controller, {bool composing = false}) {
  final selection = controller.selection;
  if (composing || !selection.isCollapsed || selection.baseOffset <= 0) {
    return false;
  }
  final caret = selection.baseOffset;
  if (caret >= controller.document.length) return false;
  final segment = controller.document.querySegmentLeafNode(caret - 1);
  final line = segment.line;
  if (line == null ||
      line.style.containsKey(Attribute.codeBlock.key) ||
      (line.parent?.style.containsKey(Attribute.codeBlock.key) ?? false)) {
    return false;
  }
  if (segment.leaf?.style.containsKey(Attribute.inlineCode.key) ?? false) {
    return false;
  }
  final start = line.documentOffset;
  final prefix = line.toPlainText().substring(0, caret - start);
  final block = switch (prefix) {
    '# ' => Attribute.h1,
    '## ' => Attribute.h2,
    '### ' => Attribute.h3,
    '- ' || '* ' => Attribute.ul,
    '1. ' => Attribute.ol,
    '> ' => Attribute.blockQuote,
    '[] ' || '[ ] ' || '- [ ] ' => Attribute.unchecked,
    '[x] ' || '[X] ' || '- [x] ' => Attribute.checked,
    '``` ' || '```\n' => Attribute.codeBlock,
    _ => null,
  };
  if (block != null) {
    controller.replaceText(
      start,
      prefix.length,
      '',
      TextSelection.collapsed(offset: start),
    );
    controller.formatText(start, 0, block);
    return true;
  }
  for (final (pattern, attribute, markerLength) in [
    (r'\*\*([^*\n]+)\*\*$', Attribute.bold, 2),
    (r'__([^_\n]+)__$', Attribute.bold, 2),
    (r'~~([^~\n]+)~~$', Attribute.strikeThrough, 2),
    (r'`([^`\n]+)`$', Attribute.inlineCode, 1),
    (r'\*([^*\n]+)\*$', Attribute.italic, 1),
    (r'_([^_\n]+)_$', Attribute.italic, 1),
  ]) {
    final match = RegExp(pattern).firstMatch(prefix);
    if (match == null ||
        (match.start > 0 &&
            (prefix[match.start - 1] == r'\' ||
                prefix[match.start - 1] == prefix[match.start]))) {
      continue;
    }
    controller.compose(
      Delta()
        ..retain(start + match.start)
        ..delete(markerLength)
        ..retain(match.group(1)!.length, {attribute.key: attribute.value})
        ..delete(markerLength),
      TextSelection.collapsed(offset: caret - markerLength * 2),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.clone(attribute, null));
    return true;
  }
  return false;
}
