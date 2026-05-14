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

/// Toggle an HTML comment around the line containing [caret]. Markdown
/// renderers treat `<!-- ... -->` as a no-op so this is a portable way
/// to "comment out" a line without losing it. The caret stays on the
/// same line and shifts by ±5 (the length of `<!-- `) when on/past the
/// inserted prefix, so users keep their place naturally.
LineOpResult toggleCommentLine(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final line = text.substring(lineStart, lineEnd);
  final leadingWs = line.length - line.trimLeft().length;
  final commentRe = RegExp(r'^(\s*)<!--\s?(.*?)\s?-->(\s*)$');
  final match = commentRe.firstMatch(line);
  final String newLine;
  final int newCaret;
  if (match != null) {
    final lead = match.group(1) ?? '';
    final inner = match.group(2) ?? '';
    final trail = match.group(3) ?? '';
    newLine = '$lead$inner$trail';
    // Shift caret left by the length of "<!-- " if it sat past the
    // marker; the trailing " -->" never shifts the caret-on-line
    // position (it was after content).
    final col = caret - lineStart;
    final inserted = lead.length + 5; // "<!-- "
    if (col <= lead.length) {
      newCaret = lineStart + col;
    } else if (col <= inserted) {
      newCaret = lineStart + lead.length;
    } else {
      final shift = 5 + (col > inserted + inner.length ? 4 : 0); // " -->"
      newCaret = (lineStart + col - shift).clamp(lineStart, lineStart + newLine.length);
    }
  } else {
    final lead = line.substring(0, leadingWs);
    final rest = line.substring(leadingWs);
    newLine = '$lead<!-- $rest -->';
    final col = caret - lineStart;
    newCaret =
        col <= leadingWs ? lineStart + col : lineStart + col + 5;
  }
  final newText =
      text.replaceRange(lineStart, lineEnd, newLine);
  return LineOpResult(text: newText, caret: newCaret);
}

/// Return the half-open `[start, end)` byte offsets of the line
/// containing [caret]. The line excludes the trailing '\n'. Empty
/// strings return `(0, 0)`.
({int start, int end}) lineRangeAt(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final start = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final end = nextNl == -1 ? text.length : nextNl;
  return (start: start, end: end);
}

/// Delete the entire line containing [caret] and place the caret on
/// the line that takes its place at the same column. For a middle line
/// the caret moves down to the following line; for the final line it
/// moves up to the (new) last line. Empties the text when there's only
/// one line.
LineOpResult deleteLineAt(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final column = caret - lineStart;
  if (nextNl != -1) {
    // Middle line — remove the line plus its trailing '\n'.
    final newText =
        text.substring(0, lineStart) + text.substring(lineEnd + 1);
    final newNextNl = newText.indexOf('\n', lineStart);
    final newLineLen =
        (newNextNl == -1 ? newText.length : newNextNl) - lineStart;
    final newCaret =
        lineStart + (column < newLineLen ? column : newLineLen);
    return LineOpResult(text: newText, caret: newCaret);
  }
  // Last line. Remove the leading '\n' too if there's a previous line.
  if (lineStart == 0) {
    return const LineOpResult(text: '', caret: 0);
  }
  final newText = text.substring(0, lineStart - 1);
  final newLineStart = newText.lastIndexOf('\n') + 1;
  final newLineLen = newText.length - newLineStart;
  final newCaret =
      newLineStart + (column < newLineLen ? column : newLineLen);
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
