/// Pure transformations on a (text, caret-offset) pair for the
/// source-mode editor. Kept dependency-free so the logic can be
/// unit-tested without a widget tree.
library;

/// Result of a line-op: the new text and the new collapsed-selection
/// caret offset.
class LineOpResult {
  const LineOpResult({required this.text, required this.caret});
  final String text;
  final int caret;
}

/// Duplicate the line containing [caret] and place the caret at the
/// same column on the new line below. If the original line lacks a
/// trailing newline (i.e. the file ends mid-line), one is inserted
/// between the original and the copy.
LineOpResult duplicateLineAt(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  // Line bounds: from the char after the previous '\n' (or 0) to the
  // next '\n' (or text.length). `lastIndexOf('\n', -1)` would throw, so
  // short-circuit when the caret is already at the start.
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final line = text.substring(lineStart, lineEnd);
  final column = caret - lineStart;
  // Splice: text[..lineEnd] + '\n' + line + text[lineEnd..]
  final insertion = nextNl == -1 ? '\n$line' : '\n$line';
  final newText = text.replaceRange(lineEnd, lineEnd, insertion);
  // New caret = lineEnd + 1 (past the inserted newline) + column.
  final newCaret = lineEnd + 1 + column;
  return LineOpResult(text: newText, caret: newCaret);
}
