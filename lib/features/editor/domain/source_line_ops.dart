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

/// Replace the leading markdown block-marker on the line containing
/// [caret] with [prefix]. Strips any existing `#{1,3} `, `- `, `* `,
/// `<n>. `, `- [ ] `, `- [x] `, or `> ` prefix first so the conversion
/// is idempotent — e.g. `# foo` → `applyLinePrefix(text, caret, '## ')`
/// → `## foo`, never `## # foo`. Pass `''` to strip back to plain text.
///
/// The caret stays at the same column relative to the START of the
/// line's content (not relative to the prefix), so a user pressing
/// ⌘⇧2 while editing word 3 of a paragraph keeps editing word 3.
LineOpResult applyLinePrefix(String text, int caret, String prefix) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final line = text.substring(lineStart, lineEnd);
  // Strip leading whitespace before pattern matching so indented list
  // items still get rewritten cleanly.
  final indentLen = line.length - line.trimLeft().length;
  final body = line.substring(indentLen);
  // Order matters: longer callout pattern must precede the bare `> ` so
  // alternation doesn't eat only the `> ` and leave `[!KIND] ` behind.
  final stripRe = RegExp(
      r'^(> \[!\w+\] |#{1,3} |- \[ \] |- \[x\] |- |\* |\d+\. |> )');
  final m = stripRe.firstMatch(body);
  final stripped = m == null ? body : body.substring(m.end);
  final newLine = '${line.substring(0, indentLen)}$prefix$stripped';
  final newText = text.replaceRange(lineStart, lineEnd, newLine);
  // Caret tracks the body. Compute the old column-of-body and re-apply
  // it after the prefix swap. If caret was inside the old prefix it
  // lands at body offset 0.
  final oldBodyStart = lineStart + indentLen + (m?.end ?? 0);
  final caretInBody = (caret - oldBodyStart).clamp(0, stripped.length);
  final newCaret = lineStart + indentLen + prefix.length + caretInBody;
  return LineOpResult(text: newText, caret: newCaret);
}

/// Toggle the checkbox state of the to-do line under [caret]:
///   * `- [ ] foo` → `- [x] foo`
///   * `- [x] foo` → `- [ ] foo`
/// Returns `null` for plain / non-todo lines so callers fall through.
/// Indentation is preserved. The caret column relative to the body
/// stays the same (the marker is the same length either way).
LineOpResult? toggleTodoAt(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final nextNl = text.indexOf('\n', caret);
  final lineEnd = nextNl == -1 ? text.length : nextNl;
  final line = text.substring(lineStart, lineEnd);
  final m = RegExp(r'^(\s*)- \[([ xX])\] ').firstMatch(line);
  if (m == null) return null;
  final indent = m.group(1)!;
  final mark = m.group(2)!.toLowerCase();
  final newMark = mark == 'x' ? ' ' : 'x';
  final newLine = '$indent- [$newMark] ${line.substring(m.end)}';
  final newText = text.replaceRange(lineStart, lineEnd, newLine);
  return LineOpResult(text: newText, caret: caret);
}

/// Smart-Enter continuation for markdown list lines. Inspect the
/// portion of the current line BEFORE [caret]; if it's a recognised
/// list item (`- `, `* `, `<n>. `, `- [ ] `, `- [x] `), return the
/// transformation that:
///   * inserts `\n<indent><next-marker>` after the caret when the body
///     is non-empty (continue the list), or
///   * strips the marker from the current line and replaces it with a
///     bare `\n` when the body is empty (terminate the list — the
///     standard "press Enter on an empty bullet to exit" UX).
/// Returns `null` when the line doesn't match any known list pattern;
/// callers should fall through to the platform's default Enter
/// behaviour in that case.
///
/// Notes:
/// * Ordered-list numbering auto-increments by 1 — re-numbering
///   subsequent items is not done here.
/// * `- [x] ` continues as `- [ ] ` (fresh unchecked todo).
LineOpResult? continueListAtNewline(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final upToCaret = text.substring(lineStart, caret);
  // Order matters: `- [ ] ` before `- ` so the alternation matches the
  // longest first.
  final re = RegExp(r'^(\s*)(- \[ \] |- \[x\] |- |\* |(\d+)\. )(.*)$');
  final m = re.firstMatch(upToCaret);
  if (m == null) return null;
  final indent = m.group(1)!;
  final marker = m.group(2)!;
  final num = m.group(3);
  final body = m.group(4)!;
  if (body.isEmpty) {
    // Strip the marker and the indent from the current line, then drop
    // a fresh newline. Net effect: the cursor lands on the next empty
    // line with no list marker — list terminated.
    final newText = text.replaceRange(lineStart, caret, '\n');
    return LineOpResult(text: newText, caret: lineStart + 1);
  }
  final nextMarker = marker == '- [x] '
      ? '- [ ] '
      : (num == null ? marker : '${int.parse(num) + 1}. ');
  final insertion = '\n$indent$nextMarker';
  final newText = text.replaceRange(caret, caret, insertion);
  return LineOpResult(text: newText, caret: caret + insertion.length);
}

/// Join the line containing [caret] with the line below. The trailing
/// '\n' is replaced with a single space, and any leading whitespace
/// (including a continuation list marker) on the next line is stripped
/// so the join reads as flowing prose. Caret lands at the join point
/// (where the space now sits). No-op on the final content line.
LineOpResult joinLineWithNext(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final nextNl = text.indexOf('\n', caret);
  if (nextNl == -1) return LineOpResult(text: text, caret: caret);
  // End of current line:
  final endOfCurrent = nextNl;
  // Skip the '\n' and any leading whitespace on the next line.
  var startOfNext = nextNl + 1;
  while (startOfNext < text.length &&
      (text[startOfNext] == ' ' || text[startOfNext] == '\t')) {
    startOfNext++;
  }
  // If the current line ends without a trailing space, insert one as the
  // separator. If it already ends in whitespace, no separator needed.
  final endsInWs =
      endOfCurrent > 0 && (text[endOfCurrent - 1] == ' ' ||
              text[endOfCurrent - 1] == '\t');
  final separator = endsInWs ? '' : ' ';
  final newText =
      text.replaceRange(endOfCurrent, startOfNext, separator);
  // Caret lands at the original end-of-current — which is the inserted
  // space (or the join point when no space was needed).
  return LineOpResult(text: newText, caret: endOfCurrent);
}

/// Backspace handling for list lines. If [caret] sits at the end of an
/// otherwise-empty list marker (e.g. `- `, `1. `, `- [ ] `), strip the
/// marker but keep the leading indent — the standard "backspace at the
/// start of an empty bullet to step out of the list" UX. Returns `null`
/// for any other line shape so callers fall through to the platform's
/// default Backspace behaviour.
LineOpResult? backspaceListMarker(String text, int caret) {
  if (caret < 0) caret = 0;
  if (caret > text.length) caret = text.length;
  final lineStart =
      caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  final upToCaret = text.substring(lineStart, caret);
  // Note: the body group must be empty for backspace to strip the
  // marker. Anything else (a space the user added by mistake, content
  // after the marker) means the user is actively editing — pass.
  final re = RegExp(r'^(\s*)(- \[ \] |- \[x\] |- |\* |\d+\. )$');
  final m = re.firstMatch(upToCaret);
  if (m == null) return null;
  final indent = m.group(1)!;
  final newText = text.replaceRange(lineStart, caret, indent);
  return LineOpResult(text: newText, caret: lineStart + indent.length);
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

/// Result of [sortLinesIn]: the new text and the new selection range
/// (the same character span, since sorting doesn't change length).
class SortLinesResult {
  const SortLinesResult({
    required this.text,
    required this.selectionStart,
    required this.selectionEnd,
  });
  final String text;
  final int selectionStart;
  final int selectionEnd;
}

/// Apply [transform] to the block of lines that the selection
/// [start..end] touches. Shared core for sort / reverse / dedupe.
/// Selection-widening rules match VS Code's "select N lines" gesture.
SortLinesResult _transformLinesIn(
  String text,
  int start,
  int end,
  List<String> Function(List<String>) transform,
) {
  if (text.isEmpty) {
    return SortLinesResult(text: text, selectionStart: 0, selectionEnd: 0);
  }
  final lo = start.clamp(0, text.length);
  final hi = end.clamp(lo, text.length);
  // Widen lo backward to the line start.
  final blockStart = lo == 0 ? 0 : text.lastIndexOf('\n', lo - 1) + 1;
  // Widen hi forward to the line end, EXCLUDING the trailing newline
  // when hi is already at a line boundary (to honour the "select N
  // lines" gesture).
  int blockEnd;
  if (hi == blockStart) {
    blockEnd = text.indexOf('\n', hi);
    if (blockEnd == -1) blockEnd = text.length;
  } else if (hi > 0 && text[hi - 1] == '\n') {
    blockEnd = hi - 1;
  } else {
    final nextNl = text.indexOf('\n', hi);
    blockEnd = nextNl == -1 ? text.length : nextNl;
  }
  if (blockStart >= blockEnd) {
    return SortLinesResult(
      text: text,
      selectionStart: blockStart,
      selectionEnd: blockEnd,
    );
  }
  final block = text.substring(blockStart, blockEnd);
  final lines = transform(block.split('\n'));
  final out = lines.join('\n');
  final newText = text.replaceRange(blockStart, blockEnd, out);
  return SortLinesResult(
    text: newText,
    selectionStart: blockStart,
    selectionEnd: blockStart + out.length,
  );
}

/// Sort the lines that the selection [start..end] touches. The
/// selection is widened outward to whole-line boundaries before
/// sorting; the new selection covers the same span (still whole
/// lines) so the user can re-sort or undo without losing context.
///
/// - Sort is case-insensitive ascending.
/// - When [end] sits at a line start (the user dragged to the very
///   start of the next line), the bottom row is NOT included so the
///   common "select N lines from above" gesture matches expectation.
/// - Empty selection ([start] == [end]): sort only the line under
///   the caret with itself (no-op), returning the same selection.
SortLinesResult sortLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return sorted;
    });

/// Remove consecutive AND non-consecutive duplicate lines in the
/// selected block, keeping the FIRST occurrence of each. Case-
/// sensitive — Notion / Vim convention.
SortLinesResult dedupeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final seen = <String>{};
      return [for (final l in lines) if (seen.add(l)) l];
    });

/// Reverse the order of the lines in the selected block. Useful for
/// flipping a sort or rendering a list bottom-up.
SortLinesResult reverseLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) => lines.reversed.toList());
