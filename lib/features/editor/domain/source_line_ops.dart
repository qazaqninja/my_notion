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

/// Swap the line containing [caret] with the line above; caret stays
/// at the same column. No-op when the caret is already on the first
/// line.
LineOpResult moveLineUp(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  if (lineStart == 0) return LineOpResult(text: text, caret: caret);
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final currentLine = text.substring(lineStart, lineEnd);
  // Previous line bounds — the '\n' before this one is at lineStart-1.
  final prevEnd = lineStart - 1;
  final prevStart =
      prevEnd == 0 ? 0 : text.lastIndexOf('\n', prevEnd - 1) + 1;
  final previousLine = text.substring(prevStart, prevEnd);
  final column = caret - lineStart;
  final newText =
      '${text.substring(0, prevStart)}$currentLine\n$previousLine${text.substring(lineEnd)}';
  final newCaret = prevStart + column;
  return LineOpResult(text: newText, caret: newCaret);
}

/// Swap the line containing [caret] with the line below; caret stays
/// at the same column. No-op when the caret is already on the last
/// content line (we consider a trailing newline's "empty line" as
/// non-content and refuse to swap into it, matching VS Code's "do
/// nothing" behaviour at the file end).
LineOpResult moveLineDown(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  if (nextNl == -1) return LineOpResult(text: text, caret: caret);
  final lineEnd = nextNl;
  final nextStart = lineEnd + 1;
  if (nextStart >= text.length) {
    // Final '\n' with no chars after — treat the trailing empty line
    // as non-content.
    return LineOpResult(text: text, caret: caret);
  }
  final secondNl = text.indexOf('\n', nextStart);
  final nextEnd = secondNl == -1 ? text.length : secondNl;
  final currentLine = text.substring(lineStart, lineEnd);
  final nextLine = text.substring(nextStart, nextEnd);
  final column = caret - lineStart;
  final newText =
      '${text.substring(0, lineStart)}$nextLine\n$currentLine${text.substring(nextEnd)}';
  final newCaret = lineStart + nextLine.length + 1 + column;
  return LineOpResult(text: newText, caret: newCaret);
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
