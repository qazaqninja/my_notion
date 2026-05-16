/// Pure transformations on a (text, caret-offset) pair for the
/// source-mode editor. Kept dependency-free so the logic can be
/// unit-tested without a widget tree.
library;

import 'dart:convert';
import 'dart:math' as math;

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

/// Sort the lines that the selection touches in **descending** order
/// (Z→A, case-insensitive). Selection-widening rules and result shape
/// mirror [sortLinesIn]; this is the natural companion for flipping
/// a previously-ascending block without an extra reverse step.
SortLinesResult sortLinesDescIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]
        ..sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
      return sorted;
    });

/// Sort the lines touched by the selection by their **absolute
/// value** when parseable as a number, ascending. Non-numeric lines
/// are pushed to the bottom (in their original order) so the
/// numeric block reads cleanly at the top. Useful when sorting by
/// magnitude regardless of sign — e.g. "biggest deviations first"
/// when running the M955 delta transform over a column of changes.
SortLinesResult sortLinesByAbsValueIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) {
          nonNumeric.add(l);
        } else {
          numeric.add((v.abs(), l));
        }
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Sort the lines touched by the selection by the **first signed
/// number** that appears anywhere in each line, ascending. Lines with
/// no number sort to the bottom in their original order. Useful for
/// log lines that start with a level/score/timestamp, or paste-in
/// data where the leading column is the sort key (e.g. "[42] foo",
/// "score: 87 alice", "-3°C Monday").
SortLinesResult sortLinesByFirstNumberIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      // Capture optional sign and a decimal run with optional fractional
      // part. Exponents are out of scope — the first plain number wins.
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        final v = m == null ? null : double.tryParse(m.group(0)!);
        if (v == null) {
          nonNumeric.add(l);
        } else {
          numeric.add((v, l));
        }
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Sort the lines touched by the selection by **word count**
/// ascending (fewest words first). Words are whitespace-separated
/// non-empty runs, matching the convention from `countLinesIn` and
/// the text-stats footer. Equal-count lines fall back to a stable
/// case-insensitive lex compare so output is deterministic. Useful
/// for prioritising a bullet list by terseness, or surfacing
/// one-word labels at the top of a paste-in.
SortLinesResult sortLinesByWordCountIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      int wc(String s) =>
          s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;
      final sorted = [...lines]
        ..sort((a, b) {
          final cmp = wc(a).compareTo(wc(b));
          if (cmp != 0) return cmp;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
      return sorted;
    });

/// Sort the lines touched by the selection by **length**, ascending
/// (shortest first). Equal-length lines fall back to a stable
/// case-insensitive lex compare for deterministic ordering.
SortLinesResult sortLinesByLengthIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]
        ..sort((a, b) {
          final cmp = a.length.compareTo(b.length);
          if (cmp != 0) return cmp;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
      return sorted;
    });

/// Sort the lines touched by the selection by **length**, descending
/// (longest first). The natural pair to [sortLinesByLengthIn].
SortLinesResult sortLinesByLengthDescIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]
        ..sort((a, b) {
          final cmp = b.length.compareTo(a.length);
          if (cmp != 0) return cmp;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
      return sorted;
    });

/// Compare two strings using natural (human-friendly) ordering: runs
/// of digits compare as integers, non-digit runs as case-insensitive
/// strings. So "file2" < "file10" and "v1.2" < "v1.10". Exposed for
/// testing; production callers go through [sortLinesNaturalIn].
int compareNatural(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final ca = a.codeUnitAt(i);
    final cb = b.codeUnitAt(j);
    final aDigit = ca >= 0x30 && ca <= 0x39;
    final bDigit = cb >= 0x30 && cb <= 0x39;
    if (aDigit && bDigit) {
      // Consume each run, compare as ints to avoid leading-zero quirks.
      var ai = i;
      while (ai < a.length) {
        final c = a.codeUnitAt(ai);
        if (c < 0x30 || c > 0x39) break;
        ai++;
      }
      var bj = j;
      while (bj < b.length) {
        final c = b.codeUnitAt(bj);
        if (c < 0x30 || c > 0x39) break;
        bj++;
      }
      final na = int.parse(a.substring(i, ai));
      final nb = int.parse(b.substring(j, bj));
      if (na != nb) return na.compareTo(nb);
      // Equal as int — fall through to length tiebreak via the
      // surrounding string compare (e.g. "01" vs "1": both 1, but
      // longer source string sorts after).
      if ((ai - i) != (bj - j)) return (ai - i).compareTo(bj - j);
      i = ai;
      j = bj;
    } else {
      final la = String.fromCharCode(ca).toLowerCase();
      final lb = String.fromCharCode(cb).toLowerCase();
      final cmp = la.compareTo(lb);
      if (cmp != 0) return cmp;
      i++;
      j++;
    }
  }
  return (a.length - i).compareTo(b.length - j);
}

/// Sort the lines that the selection touches using **natural**
/// (human-friendly) ordering: runs of digits compare as integers, so
/// "file2" sorts before "file10". Common for version strings, file
/// lists, and ordered task IDs. Selection-widening rules mirror
/// [sortLinesIn].
SortLinesResult sortLinesNaturalIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]..sort(compareNatural);
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

/// Wrap each non-blank selected line in `**…**` so its contents
/// render bold. Blank lines stay blank.
SortLinesResult boldLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '**$l**',
      ];
    });

/// Wrap each non-blank selected line in `*…*` so its contents
/// render italic. Blank lines stay blank.
SortLinesResult italicLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '*$l*',
      ];
    });

/// Wrap each non-blank selected line in `` `…` `` so its contents
/// render as inline code. Blank lines stay blank.
SortLinesResult codeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '`$l`',
      ];
    });

/// Wrap each non-blank selected line in `~~…~~` (GFM strikethrough).
/// Blank lines stay blank.
SortLinesResult strikethroughLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '~~$l~~',
      ];
    });

/// Bump every selected line that starts with one or more `#`
/// followed by a space **down** one level (H1 → H2, etc.). Lines at
/// the maximum heading depth (`###### `) stay put. Non-heading
/// lines pass through. Useful when copy-pasting a section into a
/// larger document and needing to push every heading one deeper.
SortLinesResult demoteHeadingsIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final headingPattern = RegExp(r'^(#{1,6}) ');
      return [
        for (final l in lines)
          (() {
            final m = headingPattern.firstMatch(l);
            if (m == null) return l;
            final hashes = m.group(1)!;
            if (hashes.length == 6) return l; // can't demote further
            return '$hashes#${l.substring(hashes.length)}';
          })(),
      ];
    });

/// Inverse of [demoteHeadingsIn]. Bump every selected heading line
/// **up** one level (H2 → H1, etc.). Lines already at H1 (`# `) stay
/// put. Non-heading lines pass through.
SortLinesResult promoteHeadingsIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final headingPattern = RegExp(r'^(#{1,6}) ');
      return [
        for (final l in lines)
          (() {
            final m = headingPattern.firstMatch(l);
            if (m == null) return l;
            final hashes = m.group(1)!;
            if (hashes.length == 1) return l; // can't promote further
            return '${hashes.substring(1)}${l.substring(hashes.length)}';
          })(),
      ];
    });

/// Convert a block of CSV-shaped lines into a GFM pipe table. The
/// first line is treated as the header row and produces the
/// `| --- | --- |` divider underneath. Each cell is trimmed of
/// surrounding whitespace. Lines without a comma pass through as
/// single-cell rows (so a heading line above the data degrades
/// gracefully).
///
///   apple, banana, cherry
///   1, 2, 3
///   4, 5, 6
///
/// becomes:
///
///   | apple | banana | cherry |
///   | --- | --- | --- |
///   | 1 | 2 | 3 |
///   | 4 | 5 | 6 |
SortLinesResult csvLinesToMarkdownTableIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      // Filter blanks but keep their positions in the output by
      // pre-storing them. For a markdown table we don't want blank
      // rows in the middle (they'd break the table), so drop them.
      final rows = [for (final l in lines) if (l.trim().isNotEmpty) l]
          .map((l) => l.split(',').map((c) => c.trim()).toList())
          .toList();
      if (rows.isEmpty) return lines;
      final widest = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
      final out = <String>[];
      // Header
      out.add('| ${_padRow(rows.first, widest).join(' | ')} |');
      // Divider
      out.add('| ${List.filled(widest, '---').join(' | ')} |');
      // Body
      for (final r in rows.skip(1)) {
        out.add('| ${_padRow(r, widest).join(' | ')} |');
      }
      return out;
    });

List<String> _padRow(List<String> row, int width) {
  if (row.length >= width) return row;
  return [...row, for (var i = row.length; i < width; i++) ''];
}

/// Inverse of [csvLinesToMarkdownTableIn]. Convert a GFM pipe-table
/// block back into one CSV row per data line. The `| --- | --- |`
/// divider row is dropped. Each cell is trimmed; the leading and
/// trailing `|` (and their padding spaces) are stripped.
///
///   | apple | banana |
///   | --- | --- |
///   | 1 | 2 |
///
/// becomes:
///
///   apple, banana
///   1, 2
SortLinesResult markdownTableToCsvLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      final dividerPattern = RegExp(r'^\|?(?:\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$');
      return [
        for (final l in lines)
          (() {
            final stripped = l.trim();
            // Pass through anything that doesn't look like a table row.
            if (!stripped.startsWith('|') || !stripped.endsWith('|')) {
              return l;
            }
            // Drop the divider entirely.
            if (dividerPattern.hasMatch(stripped)) return null;
            // Split on `|`, drop the empty fragments produced by the
            // leading/trailing pipe, trim each cell.
            final cells = stripped
                .substring(1, stripped.length - 1)
                .split('|')
                .map((c) => c.trim())
                .toList();
            return cells.join(', ');
          })(),
      ].whereType<String>().toList();
    });

/// Convert every line that looks like a bare URL (`http://`,
/// `https://`, or `www.`) into the markdown link form
/// `[<url>](<url>)`. Lines that don't match pass through.
///
/// Whitespace around the URL is preserved on either side. Useful
/// when a user pastes a vertical list of URLs and wants them
/// clickable in the renderer.
SortLinesResult urlsToMarkdownLinksIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      // A URL is the whole non-whitespace span of the line.
      final urlPattern = RegExp(
        r'^(\s*)(https?://\S+|www\.\S+)(\s*)$',
      );
      return [
        for (final l in lines)
          (() {
            final m = urlPattern.firstMatch(l);
            if (m == null) return l;
            final lead = m.group(1) ?? '';
            final url = m.group(2) ?? '';
            final trail = m.group(3) ?? '';
            return '$lead[$url]($url)$trail';
          })(),
      ];
    });

/// Wrap each non-blank selected line in straight double quotes
/// (`"abc"`). Internal `"` is preserved as-is. Useful for quoting
/// rows before CSV export or JSON-array construction.
SortLinesResult quoteLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '"$l"',
      ];
    });

/// Compute the arithmetic mean of every selected line that parses
/// as a number. Non-numeric lines are skipped. Always returns a
/// fixed-point result (means generally aren't whole numbers, so we
/// don't bother trying to detect that case). Returns the source
/// unchanged when no line parses as a number.
SortLinesResult averageNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double total = 0;
      var count = 0;
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) continue;
        total += v;
        count++;
      }
      if (count == 0) return lines;
      return [(total / count).toString()];
    });

/// Find the maximum numeric value in the selected block. Skips non-
/// numeric lines. Returns the source unchanged when no line parses.
SortLinesResult maxNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double? best;
      var allInt = true;
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) continue;
        if (v != v.truncateToDouble()) allInt = false;
        if (best == null || v > best) best = v;
      }
      if (best == null) return lines;
      if (allInt) return [best.toInt().toString()];
      return [best.toString()];
    });

/// Compute the median of every selected numeric line. Sorts the
/// parsed values; for an odd count returns the middle element, for
/// an even count returns the arithmetic mean of the two middle
/// elements. Non-numeric lines are skipped. Renders as integer when
/// every input was integer AND the median has no fractional part;
/// decimal otherwise. Returns the source unchanged when no line
/// parses.
SortLinesResult medianNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      var anyDecimalInput = false;
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) continue;
        // Track "user typed a decimal" from the source — relying on
        // the numeric value would lose the distinction between "1"
        // and "1.0".
        if (trimmed.contains('.')) anyDecimalInput = true;
        values.add(v);
      }
      if (values.isEmpty) return lines;
      values.sort();
      final n = values.length;
      final double median;
      if (n.isOdd) {
        median = values[n ~/ 2];
      } else {
        median = (values[n ~/ 2 - 1] + values[n ~/ 2]) / 2;
      }
      if (!anyDecimalInput && median == median.truncateToDouble()) {
        return [median.toInt().toString()];
      }
      return [median.toString()];
    });

/// Find the minimum numeric value in the selected block. Skips non-
/// numeric lines. Returns the source unchanged when no line parses.
SortLinesResult minNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double? best;
      var allInt = true;
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) continue;
        if (v != v.truncateToDouble()) allInt = false;
        if (best == null || v < best) best = v;
      }
      if (best == null) return lines;
      if (allInt) return [best.toInt().toString()];
      return [best.toString()];
    });

/// Replace the selected block with the integer count of its non-
/// blank lines. Useful for "how many items did I just paste?"
/// scratch work — pairs with the M938–M940 statistics quartet so a
/// column of values gives both the aggregate and the cardinality.
SortLinesResult countLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final n = lines.where((l) => l.trim().isNotEmpty).length;
      return [n.toString()];
    });

/// Tally every distinct non-blank line in the selection and emit
/// `count× line` rows sorted by descending count. Ties break by
/// the original line text in case-insensitive ascending order so
/// the output is deterministic. Useful for quick log-analysis
/// scratch ("how many of each kind in this dump?").
///
///   apple
///   banana
///   apple
///   cherry
///
/// becomes:
///
///   2× apple
///   1× banana
///   1× cherry
SortLinesResult frequencyLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final counts = <String, int>{};
      for (final l in lines) {
        if (l.trim().isEmpty) continue;
        counts[l] = (counts[l] ?? 0) + 1;
      }
      if (counts.isEmpty) return lines;
      final entries = counts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        });
      return [for (final e in entries) '${e.value}× ${e.key}'];
    });

/// Multiply every selected numeric line into a single product.
/// Non-numeric lines are skipped. Renders integer-form when every
/// input string was an integer (no `.`) AND the product has no
/// fractional part; decimal-form otherwise. Returns the source
/// unchanged when no line parses (preserves block structure).
SortLinesResult productNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double product = 1;
      var hasNumber = false;
      var anyDecimalInput = false;
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) continue;
        hasNumber = true;
        if (trimmed.contains('.')) anyDecimalInput = true;
        product *= v;
      }
      if (!hasNumber) return lines;
      if (!anyDecimalInput && product == product.truncateToDouble()) {
        return [product.toInt().toString()];
      }
      return [product.toString()];
    });

/// Compute the **range** (max − min) of every selected numeric
/// line. Non-numeric lines are skipped. Renders integer-form when
/// every input was integer AND the range has no fractional part,
/// decimal-form otherwise. Returns the source unchanged when no
/// line parses (preserves block structure).
SortLinesResult rangeNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double? lo;
      double? hi;
      var anyDecimalInput = false;
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) continue;
        if (trimmed.contains('.')) anyDecimalInput = true;
        if (lo == null || v < lo) lo = v;
        if (hi == null || v > hi) hi = v;
      }
      if (lo == null || hi == null) return lines;
      final range = hi - lo;
      if (!anyDecimalInput && range == range.truncateToDouble()) {
        return [range.toInt().toString()];
      }
      return [range.toString()];
    });

/// Replace every numeric line with its absolute value
/// (`abs(x)`). Non-numeric lines pass through. Renders integer-
/// form when every input was integer (no `.`) AND the abs value
/// has no fractional part; decimal-form otherwise.
SortLinesResult absNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final trimmed = l.trim();
            final v = double.tryParse(trimmed);
            if (v == null) return l;
            final a = v.abs();
            if (!trimmed.contains('.') && a == a.truncateToDouble()) {
              return a.toInt().toString();
            }
            return a.toString();
          })(),
      ];
    });

/// Replace every numeric line with its negation (`-x`). Non-
/// numeric lines pass through. Same integer/decimal-rendering
/// convention as [absNumericLinesIn].
SortLinesResult negateNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final trimmed = l.trim();
            final v = double.tryParse(trimmed);
            if (v == null) return l;
            final n = -v;
            if (!trimmed.contains('.') && n == n.truncateToDouble()) {
              return n.toInt().toString();
            }
            return n.toString();
          })(),
      ];
    });

/// Format every numeric line in scientific notation with `digits`
/// digits after the mantissa decimal (default 3). `1234 → 1.234e3`,
/// `0.000567 → 5.670e-4`. Non-numeric lines pass through.
/// `0` is rendered as `0.000e0` so the format is consistent.
SortLinesResult scientificNotationLinesIn(
  String text,
  int start,
  int end, {
  int digits = 3,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return v.toStringAsExponential(digits);
          })(),
      ];
    });

/// Format every numeric line with `,`-grouped thousands separators
/// for readability. `1234567 → 1,234,567`. The decimal portion (if
/// any) is left untouched. Negative numbers keep their leading `-`.
/// Non-numeric lines pass through.
SortLinesResult withThousandSeparatorsLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      String groupInteger(String digits) {
        if (digits.length <= 3) return digits;
        // Collect groups from the right, then reverse so the
        // most-significant group lands at the start of the output.
        final groups = <String>[];
        var i = digits.length;
        while (i > 3) {
          groups.add(digits.substring(i - 3, i));
          i -= 3;
        }
        groups.add(digits.substring(0, i));
        return groups.reversed.join(',');
      }

      return [
        for (final l in lines)
          (() {
            final trimmed = l.trim();
            final v = double.tryParse(trimmed);
            if (v == null) return l;
            // Use the source string rather than v.toString() so that
            // 1234.50 keeps its trailing zero (toString would drop it).
            var src = trimmed;
            final neg = src.startsWith('-');
            if (neg) src = src.substring(1);
            final dot = src.indexOf('.');
            final intPart = dot == -1 ? src : src.substring(0, dot);
            final fracPart = dot == -1 ? '' : src.substring(dot);
            return '${neg ? '-' : ''}${groupInteger(intPart)}$fracPart';
          })(),
      ];
    });

/// Replace every numeric line with its sign as `+`, `-`, or `0`
/// (matching the `signum` mathematical operator). Non-numeric
/// lines pass through. Useful for collapsing a noisy column of
/// values down to a sparkline-style trend indicator.
SortLinesResult signNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            if (v > 0) return '+';
            if (v < 0) return '-';
            return '0';
          })(),
      ];
    });

/// Floor every selected numeric line — round toward negative
/// infinity. `3.7 → 3`, `-3.7 → -4`. Result is always an integer
/// rendered without decimals. Non-numeric lines pass through.
SortLinesResult floorNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return v.floor().toString();
          })(),
      ];
    });

/// Ceil every selected numeric line — round toward positive
/// infinity. `3.2 → 4`, `-3.2 → -3`. Result is always an integer.
/// Non-numeric lines pass through.
SortLinesResult ceilNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return v.ceil().toString();
          })(),
      ];
    });

/// Truncate every selected numeric line — drop the fractional part
/// (round toward zero). `3.7 → 3`, `-3.7 → -3`. Different from
/// [floorNumericLinesIn] on negative inputs. Non-numeric lines
/// pass through.
SortLinesResult truncateNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return v.truncate().toString();
          })(),
      ];
    });

/// Round every selected numeric line to [decimals] places. Uses
/// banker's-friendly `toStringAsFixed` so a trailing 5 follows the
/// platform's default-rounding behaviour (away-from-zero on most
/// platforms; close enough for scratch-work). Non-numeric lines
/// pass through untouched. Default precision is 2 places.
SortLinesResult roundNumericLinesIn(
  String text,
  int start,
  int end, {
  int decimals = 2,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return v.toStringAsFixed(decimals);
          })(),
      ];
    });

/// Compute the **population** variance of every selected numeric
/// line: `mean((x - mean(x))^2)`. The square of [stdDevNumericLinesIn]'s
/// result. Always rendered as decimal. Non-numeric lines are
/// skipped; no-numeric is a no-op.
SortLinesResult varianceNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v != null) values.add(v);
      }
      if (values.isEmpty) return lines;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          values.length;
      return [variance.toString()];
    });

/// Compute the **population** standard deviation of every selected
/// numeric line: `sqrt(mean((x - mean(x))^2))`. Non-numeric lines
/// are skipped. Returns the source unchanged when no line parses
/// (preserves block structure). Always rendered as decimal — std
/// devs are rarely whole numbers and forcing integer-form would be
/// misleading.
SortLinesResult stdDevNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v != null) values.add(v);
      }
      if (values.isEmpty) return lines;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          values.length;
      return [math.sqrt(variance).toString()];
    });

/// Replace each numeric line with its **z-score**:
/// `(x - mean) / stddev`, using the population standard deviation
/// (same as [stdDevNumericLinesIn]). Non-numeric lines pass through
/// — labels and dividers survive the transform so a column with a
/// header still reads correctly. Returns the source unchanged when
/// no line parses, when only one numeric line is present, or when
/// the stddev is 0 (all values identical, avoids divide-by-zero).
/// Always rendered as decimal — z-scores rarely line up on integers
/// and forcing integer-form would be misleading.
///
///   10            -1.414...
///   20      →     0.0
///   30             1.414...
SortLinesResult zScoreNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v != null) values.add(v);
      }
      if (values.length < 2) return lines;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          values.length;
      final sd = math.sqrt(variance);
      if (sd == 0) return lines;
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return ((v - mean) / sd).toString();
          })(),
      ];
    });

/// Replace each numeric line with its **rank** (1-based, ascending)
/// using **competition ranking**: ties share the same rank and the
/// next rank skips by the count of ties (`1, 2, 2, 4`). This matches
/// how leaderboards work and is the most intuitive default for a
/// terse "rank these values" gesture. Non-numeric lines pass through
/// unchanged. Returns the source unchanged when no line parses.
///
///   3            2
///   1     →      1
///   3            2
///   7            4
SortLinesResult rankNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v != null) values.add(v);
      }
      if (values.isEmpty) return lines;
      final sorted = [...values]..sort();
      // For each unique value, record its competition rank (1-based
      // position of its first occurrence in the sorted list).
      final rankOf = <double, int>{};
      for (var i = 0; i < sorted.length; i++) {
        rankOf.putIfAbsent(sorted[i], () => i + 1);
      }
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return rankOf[v]!.toString();
          })(),
      ];
    });

/// Replace each numeric line with its **min-max normalised** value,
/// scaled to the [0, 1] range: `(x - min) / (max - min)`. Non-numeric
/// lines pass through unchanged so header rows and dividers survive.
/// Returns the source unchanged when fewer than two numeric lines
/// are present (a single value can't define a range), or when
/// `max == min` (every value identical — collapse would lose info
/// and force a divide-by-zero). Always rendered as decimal —
/// normalised scores almost never land on integers.
///
///   0             0.0
///   25       →    0.25
///   100           1.0
SortLinesResult normalizeNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final values = <double>[];
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v != null) values.add(v);
      }
      if (values.length < 2) return lines;
      final lo = values.reduce(math.min);
      final hi = values.reduce(math.max);
      if (hi == lo) return lines;
      final span = hi - lo;
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            return ((v - lo) / span).toString();
          })(),
      ];
    });

/// Replace each numeric line with its share of the column total,
/// rendered as a percentage with one decimal place (`xx.x%`).
/// Non-numeric lines pass through. Returns the source unchanged
/// when the column total is 0 (avoids the divide-by-zero) OR when
/// no line parses (preserves block structure).
///
///   10        25.0%
///   30   →    75.0%
SortLinesResult percentageOfTotalLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      double total = 0;
      var anyNumeric = false;
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) continue;
        anyNumeric = true;
        total += v;
      }
      if (!anyNumeric || total == 0) return lines;
      return [
        for (final l in lines)
          (() {
            final v = double.tryParse(l.trim());
            if (v == null) return l;
            final pct = (v / total) * 100;
            return '${pct.toStringAsFixed(1)}%';
          })(),
      ];
    });

/// Emit consecutive deltas (`x[i+1] - x[i]`) for every adjacent
/// pair of parseable numeric lines in the selection. Non-numeric
/// lines pass through and DO break the pair (so deltas don't span
/// across labels — a "section divider" line stops the run).
/// Output length is one less than the longest run of consecutive
/// numeric lines.
///
///   1            +4
///   5     →      +5
///   10
///
/// Integer / decimal rendering follows the family convention. The
/// `+` prefix on positive values keeps the output readable as
/// signed deltas; negative deltas render with the native `-`.
SortLinesResult deltaNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      String fmt(double v, {required bool decimal}) {
        final body = !decimal && v == v.truncateToDouble()
            ? v.toInt().toString()
            : v.toString();
        return v >= 0 ? '+$body' : body;
      }

      final out = <String>[];
      var anyNumeric = false;
      double? prev;
      var prevDecimal = false;
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) {
          out.add(l);
          prev = null; // break the run
          continue;
        }
        anyNumeric = true;
        final isDecimal = trimmed.contains('.');
        if (prev != null) {
          out.add(fmt(v - prev, decimal: prevDecimal || isDecimal));
        }
        prev = v;
        prevDecimal = isDecimal;
      }
      if (!anyNumeric) return lines;
      return out;
    });

/// Replace every numeric line with the running product of itself
/// and every preceding numeric line. Multiplicative companion to
/// [cumulativeSumLinesIn]. Non-numeric lines pass through and do
/// NOT advance the counter.
///
///   2            2
///   3     →      6
///   4            24
///
/// Integer / decimal rendering follows the family convention.
SortLinesResult cumulativeProductLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      var anyDecimalInput = false;
      var anyNumeric = false;
      double product = 1;
      final out = <String>[];
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) {
          out.add(l);
          continue;
        }
        anyNumeric = true;
        if (trimmed.contains('.')) anyDecimalInput = true;
        product *= v;
        if (!anyDecimalInput && product == product.truncateToDouble()) {
          out.add(product.toInt().toString());
        } else {
          out.add(product.toString());
        }
      }
      if (!anyNumeric) return lines;
      return out;
    });

/// Replace every numeric line with the running total of all
/// preceding numeric lines plus itself. Non-numeric lines pass
/// through and don't advance the counter. Useful for "sum to date"
/// or financial-style tally columns.
///
///   1            1
///   2     →      3
///   3            6
///
/// Renders integer-form when every input was integer AND each
/// running total has no fractional part. Decimal-form otherwise.
/// Returns the source unchanged when no line parses (preserves the
/// block instead of producing an empty output).
SortLinesResult cumulativeSumLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      var anyDecimalInput = false;
      var anyNumeric = false;
      double total = 0;
      final out = <String>[];
      for (final l in lines) {
        final trimmed = l.trim();
        final v = double.tryParse(trimmed);
        if (v == null) {
          out.add(l);
          continue;
        }
        anyNumeric = true;
        if (trimmed.contains('.')) anyDecimalInput = true;
        total += v;
        if (!anyDecimalInput && total == total.truncateToDouble()) {
          out.add(total.toInt().toString());
        } else {
          out.add(total.toString());
        }
      }
      if (!anyNumeric) return lines;
      return out;
    });

/// Sum every selected line that parses as a number (int or double).
/// Non-numeric lines are skipped. Outputs a single line with the
/// running total — integer when the sum has no fractional part,
/// fixed-point otherwise. Returns the source unchanged when no line
/// parses as a number (preserves block structure).
SortLinesResult sumNumericLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      var hasNumber = false;
      var hasFraction = false;
      double total = 0;
      for (final l in lines) {
        final v = double.tryParse(l.trim());
        if (v == null) continue;
        hasNumber = true;
        if (v != v.truncateToDouble()) hasFraction = true;
        total += v;
      }
      if (!hasNumber) return lines;
      // Pick an integer rendering when the total has no fractional
      // part AND no input had one. (3.0 + (-3.0) = 0 but the user
      // gave us decimals, so render "0.0" not "0".)
      if (!hasFraction && total == total.truncateToDouble()) {
        return [total.toInt().toString()];
      }
      return [total.toString()];
    });

/// Inverse of [linesToJsonArrayIn]. Parse the selected block as a
/// JSON array of strings and emit one element per line. The whole
/// selection is concatenated before parsing so a multi-line array
/// works too. Falls back to passing the source through unchanged
/// when the input doesn't parse — keeps mixed-content selections
/// safe.
SortLinesResult jsonArrayToLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final joined = lines.join('\n').trim();
      if (!joined.startsWith('[') || !joined.endsWith(']')) return lines;
      try {
        final decoded = jsonDecode(joined);
        if (decoded is! List) return lines;
        return [for (final v in decoded) '$v'];
      } on FormatException {
        return lines;
      }
    });

/// Collapse a block of non-blank selected lines into a single
/// JSON-style array (`["a", "b", "c"]`). Each cell is trimmed, then
/// any internal `"` is escaped as `\"` and `\` is escaped as `\\`
/// so the output parses cleanly with `dart:convert`'s `JsonDecoder`.
/// Blank lines are dropped (they'd produce empty array elements).
/// Returns the source unchanged when there are no non-blank lines.
SortLinesResult linesToJsonArrayIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final cells =
          [for (final l in lines) l.trim()].where((l) => l.isNotEmpty);
      if (cells.isEmpty) return lines;
      String escape(String s) =>
          s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      return ['[${cells.map((c) => '"${escape(c)}"').join(', ')}]'];
    });

/// Inverse of [quoteLinesIn]: strip a single pair of surrounding
/// straight double quotes when both ends of a line are `"`.
/// Single-sided quotes and inner quotes pass through.
SortLinesResult unquoteLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            if (l.length >= 2 && l.startsWith('"') && l.endsWith('"')) {
              return l.substring(1, l.length - 1);
            }
            return l;
          })(),
      ];
    });

/// Wrap each non-blank selected line in `==…==` (Pandoc highlight,
/// rendered yellow by markdown_renderer). Blank lines stay blank.
SortLinesResult highlightLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '==$l==',
      ];
    });

/// Strip the outer markdown-formatting marks from each selected line
/// when the **entire** line is wrapped in one of the M909/M910
/// wrappers. Recognises `**…**`, `*…*`, `~~…~~`, `==…==`, and
/// `` `…` ``. Strips only one layer at a time so repeated invocations
/// step nested wrappers outward.
///
/// Lines that aren't fully-wrapped pass through untouched, so a
/// mixed-content selection is safe to invoke.
SortLinesResult unwrapInlineFormattingLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      const pairs = <(String, String)>[
        ('**', '**'),
        ('~~', '~~'),
        ('==', '=='),
        ('*', '*'),
        ('`', '`'),
      ];
      return [
        for (final l in lines)
          (() {
            for (final pair in pairs) {
              final open = pair.$1;
              final close = pair.$2;
              if (l.length >= open.length + close.length &&
                  l.startsWith(open) &&
                  l.endsWith(close)) {
                return l.substring(open.length, l.length - close.length);
              }
            }
            return l;
          })(),
      ];
    });

/// Convert a single line into `snake_case` — lowercase ASCII letters
/// and digits, with non-alphanumeric runs collapsed to a single `_`.
/// Leading/trailing underscores are trimmed. Empty / all-punctuation
/// input returns the empty string.
///
///   "My Cool Title!"  → "my_cool_title"
///   "v1.2.3 final"    → "v1_2_3_final"
String toSnakeCase(String line) {
  final lower = line.toLowerCase();
  final buf = StringBuffer();
  var inUnder = false;
  for (var i = 0; i < lower.length; i++) {
    final c = lower.codeUnitAt(i);
    final isAlnum =
        (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7a);
    if (isAlnum) {
      buf.writeCharCode(c);
      inUnder = false;
    } else if (!inUnder) {
      buf.write('_');
      inUnder = true;
    }
  }
  var out = buf.toString();
  if (out.startsWith('_')) out = out.substring(1);
  if (out.endsWith('_')) out = out.substring(0, out.length - 1);
  return out;
}

/// Convert a single line into `camelCase` — lowercase first word,
/// remaining words have their first ASCII letter uppercased and
/// the rest lowercased. Non-alphanumeric chars are the word
/// separators (matching the snake/slug input split rules).
///
///   "My Cool Title!"  → "myCoolTitle"
///   "hello_world"     → "helloWorld"
///   "v1.2.3 final"    → "v123Final"
String toCamelCase(String line) {
  // Split on any run of non-alphanumeric.
  final words = line
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final buf = StringBuffer(words.first);
  for (var i = 1; i < words.length; i++) {
    final w = words[i];
    buf
      ..write(w.substring(0, 1).toUpperCase())
      ..write(w.substring(1));
  }
  return buf.toString();
}

/// Per-line wrapper for [toSnakeCase].
SortLinesResult snakeCaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toSnakeCase(l),
      ];
    });

/// Per-line wrapper for [toCamelCase].
SortLinesResult camelCaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toCamelCase(l),
      ];
    });

/// Convert a single line into `PascalCase` — like [toCamelCase] but
/// the first word is also capital-cased.
///
///   "my cool title" → "MyCoolTitle"
///   "hello_world"   → "HelloWorld"
String toPascalCase(String line) {
  final words = line
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final buf = StringBuffer();
  for (final w in words) {
    buf
      ..write(w.substring(0, 1).toUpperCase())
      ..write(w.substring(1));
  }
  return buf.toString();
}

/// Per-line wrapper for [toPascalCase].
SortLinesResult pascalCaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toPascalCase(l),
      ];
    });

/// Convert a single line into `CONSTANT_CASE` — the uppercase form of
/// [toSnakeCase], also known as SCREAMING_SNAKE_CASE. Common for env
/// var names, top-level constants, and Bash variables.
///
///   "my cool title"  → "MY_COOL_TITLE"
///   "hello-world"    → "HELLO_WORLD"
String toConstantCase(String line) => toSnakeCase(line).toUpperCase();

/// Per-line wrapper for [toConstantCase].
SortLinesResult constantCaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toConstantCase(l),
      ];
    });

/// Convert a single line into a URL-safe slug:
///
///   "My Cool Title!" → "my-cool-title"
///   "v1.2.3 (final)" → "v1-2-3-final"
///   "Hello — World"   → "hello-world"
///
/// Rules: lowercase, replace any run of non-ASCII-alphanumeric chars
/// with a single `-`, then trim leading/trailing `-`. Exposed so the
/// per-line transform can call into it; lives next to the line ops
/// so callers don't import a separate helper file.
String slugifyLine(String line) {
  final lower = line.toLowerCase();
  final buf = StringBuffer();
  var inDash = false;
  for (var i = 0; i < lower.length; i++) {
    final c = lower.codeUnitAt(i);
    final isAlnum =
        (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x7a);
    if (isAlnum) {
      buf.writeCharCode(c);
      inDash = false;
    } else if (!inDash) {
      buf.write('-');
      inDash = true;
    }
  }
  var out = buf.toString();
  if (out.startsWith('-')) out = out.substring(1);
  if (out.endsWith('-')) out = out.substring(0, out.length - 1);
  return out;
}

/// Apply [slugifyLine] to every line in the selected block — useful
/// for converting a list of titles into a list of permalink fragments
/// in one gesture. Blank lines stay blank.
SortLinesResult slugifyLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else slugifyLine(l),
      ];
    });

/// Shuffle the lines in the selected block uniformly at random.
///
/// When [random] is `null`, a system-seeded [Random] is used; tests
/// pass a `Random(seed)` for deterministic ordering. Lines are
/// shuffled in-place via the standard Fisher–Yates implementation in
/// `List.shuffle`. Empty lines are shuffled along with the rest —
/// they are first-class members of the block.
SortLinesResult shuffleLinesIn(
  String text,
  int start,
  int end, {
  math.Random? random,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      final shuffled = [...lines]..shuffle(random);
      return shuffled;
    });

/// Strip trailing whitespace (spaces, tabs) from every line in the
/// selected block. Common cleanup before committing — many tools
/// reject trailing whitespace and it's invisible in the editor.
SortLinesResult trimTrailingWhitespaceIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) l.replaceFirst(RegExp(r'[ \t]+$'), '')],
    );

/// Collapse runs of 2+ consecutive blank lines in the selected
/// block down to a single blank line. Common cleanup when paste
/// introduces extra paragraph breaks or when a document accumulates
/// "decorative" whitespace. Non-blank lines are untouched; the
/// trailing newline after the selection is preserved.
SortLinesResult collapseBlankLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final out = <String>[];
      var prevBlank = false;
      for (final l in lines) {
        final blank = l.trim().isEmpty;
        if (blank && prevBlank) continue;
        out.add(l);
        prevBlank = blank;
      }
      return out;
    });

/// Drop every blank line in the selected block. The complementary
/// "stronger" variant of [collapseBlankLinesIn] — useful when you
/// want a pure compact form with zero vertical breathing room.
SortLinesResult dropBlankLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) if (l.trim().isNotEmpty) l],
    );

/// Prefix every non-blank selected line with `// ` so the block
/// reads as a code-style comment. Blank lines stay blank. Useful
/// when pasting prose alongside snippets and wanting to mark
/// sections as commentary.
SortLinesResult commentLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else '// $l',
      ];
    });

/// Wrap each non-blank selected line in `<!-- … -->`. Useful for
/// hiding notes in markdown bodies (commented-out content is
/// invisible in the rendered view but stays in the source).
/// Blank lines stay blank.
SortLinesResult htmlCommentLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '<!-- $l -->',
      ];
    });

/// Inverse of [htmlCommentLinesIn]: strip the `<!-- … -->` wrapper
/// from every line where it fully wraps the line. Non-matching
/// lines pass through.
SortLinesResult htmlUncommentLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final wrap = RegExp(r'^<!--\s?(.*?)\s?-->$');
      return [
        for (final l in lines)
          (() {
            final m = wrap.firstMatch(l);
            return m == null ? l : m.group(1) ?? l;
          })(),
      ];
    });

/// Inverse of [commentLinesIn]. Strip a leading `// ` (or `//`
/// without space) from every line that starts with one. Blank
/// lines and uncommented lines pass through.
SortLinesResult uncommentLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            // Handle both `// foo` and `//foo` (no space).
            if (l.startsWith('// ')) return l.substring(3);
            if (l.startsWith('//')) return l.substring(2);
            return l;
          })(),
      ];
    });

/// Collapse internal runs of spaces and tabs on every selected
/// line into a single space. Useful when pasting text whose
/// formatting used multi-space alignment that no longer makes sense
/// in markdown prose. Leading whitespace is preserved (so indented
/// list markers stay aligned); only **internal** runs collapse.
SortLinesResult collapseSpacesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final internalRun = RegExp(r'(?<=\S)[ \t]{2,}');
      return [
        for (final l in lines) l.replaceAll(internalRun, ' '),
      ];
    });

/// Strip leading whitespace (spaces, tabs) from every line in the
/// selected block. The trim-trailing's mirror — common when pasting
/// pre-indented code into the editor and wanting a clean left margin.
SortLinesResult stripLeadingWhitespaceIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) l.replaceFirst(RegExp(r'^[ \t]+'), '')],
    );

/// Replace every tab character on every selected line with [width]
/// spaces (defaults to 2 — the editor's indent width). Useful for
/// pasted code that mixes tabs and spaces, since `flutter analyze`
/// rejects tabs in Dart source.
SortLinesResult tabsToSpacesIn(String text, int start, int end, {int width = 2}) {
  final replacement = ' ' * width;
  return _transformLinesIn(
    text,
    start,
    end,
    (lines) => [for (final l in lines) l.replaceAll('\t', replacement)],
  );
}

/// Escape HTML-significant characters on every selected line:
///
///   `&`   → `&amp;`   (MUST come first)
///   `<`   → `&lt;`
///   `>`   → `&gt;`
///   `"`   → `&quot;`
///   `'`   → `&#39;`
///
/// Useful when copying source code or HTML-templating into prose.
SortLinesResult htmlEscapeLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [
        for (final l in lines)
          l
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('"', '&quot;')
              .replaceAll("'", '&#39;'),
      ],
    );

/// Inverse of [htmlEscapeLinesIn]: replace the five named/numeric
/// entities back to their original characters. `&amp;` must come
/// LAST so we don't accidentally re-decode `&amp;lt;`-style nested
/// escapes prematurely. The decode pass also handles `&#39;` (the
/// numeric form) and the equivalent `&apos;` for compatibility.
SortLinesResult htmlUnescapeLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [
        for (final l in lines)
          l
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'")
              .replaceAll('&apos;', "'")
              .replaceAll('&amp;', '&'),
      ],
    );

/// Reverse the **words** on every selected line, preserving the
/// inter-word whitespace runs and any trailing newline. Different
/// from [reverseCharactersInLineIn] (per-char flip) and
/// [reverseLinesIn] (order flip).
///
///   `hello world` → `world hello`
///   `one two three` → `three two one`
SortLinesResult reverseWordsInLineIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty)
            l
          else
            l.trimRight().split(' ').reversed.join(' ') +
                l.substring(l.trimRight().length),
      ];
    });

/// Reverse the characters of each selected line in place. Different
/// from [reverseLinesIn], which reverses the **order** of lines.
/// Useful for the classic "reveal hidden text" gag and for testing
/// palindromes.
SortLinesResult reverseCharactersInLineIn(String text, int start, int end) =>
    _transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) l.split('').reversed.join()],
    );

/// Apply the ROT13 cipher to every selected line — each ASCII letter
/// is rotated by 13 positions, so a→n, n→a, A→N, N→A. Non-letters
/// pass through unchanged. ROT13 is its own inverse — applying it
/// twice returns the original text.
String rot13(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0x41 && c <= 0x5a) {
      // Uppercase A-Z.
      out.writeCharCode(((c - 0x41 + 13) % 26) + 0x41);
    } else if (c >= 0x61 && c <= 0x7a) {
      // Lowercase a-z.
      out.writeCharCode(((c - 0x61 + 13) % 26) + 0x61);
    } else {
      out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// Apply [rot13] per line over the selected block.
SortLinesResult rot13LinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) rot13(l)],
    );

/// URL-encode every non-blank selected line via `Uri.encodeComponent`
/// so the value is safe to drop into a query string or path segment
/// (spaces become `%20`, slashes `%2F`, etc.). Blank lines stay blank
/// so block structure is preserved.
SortLinesResult urlEncodeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.isEmpty) l else Uri.encodeComponent(l),
      ];
    });

/// Inverse of [urlEncodeLinesIn]: decode `%XX` triplets back to the
/// original UTF-8 text. Lines that contain malformed percent
/// sequences are caught by [ArgumentError] / [FormatException] and
/// left untouched so a mixed-content selection is safe to invoke.
SortLinesResult urlDecodeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.isEmpty)
            l
          else
            (() {
              try {
                return Uri.decodeComponent(l);
                // Uri.decodeComponent throws ArgumentError on a few
                // malformed inputs; treat it like FormatException
                // and leave the source line as-is.
                // ignore: avoid_catching_errors
              } on ArgumentError {
                return l;
              } on FormatException {
                return l;
              }
            })(),
      ];
    });

/// Base64-encode every selected line using UTF-8 bytes. Lines that
/// were empty stay empty so block structure is preserved. Useful
/// when copying secrets / blob payloads into structured fields.
SortLinesResult base64EncodeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.isEmpty) l else base64.encode(utf8.encode(l)),
      ];
    });

/// Base64-decode every selected line back to its UTF-8 string. Lines
/// that fail to parse (not Base64, or contain invalid UTF-8) are
/// left untouched so a mixed-content selection is still safe to
/// invoke. Empty lines stay empty.
SortLinesResult base64DecodeLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty)
            l
          else
            (() {
              try {
                final bytes = base64.decode(l.trim());
                return utf8.decode(bytes);
              } on FormatException {
                return l;
              }
            })(),
      ];
    });

/// Convert ASCII typography into Unicode typographic equivalents:
///
///   `"abc"`     → `"abc"`
///   `'it's'`    → `'it's'`
///   `--`        → `—` (em dash)
///   `...`       → `…` (ellipsis)
///
/// Direction for `"` and `'` is decided contextually: a straight
/// quote that follows whitespace, line start, or an opening bracket
/// is treated as the **opening** form; otherwise it's the **closing**
/// form. Returned text has the same character count for em-dash and
/// straight conversions, two fewer for each `...` → `…` replacement,
/// one fewer for each `--` → `—` replacement.
String smartTypography(String body) {
  // First, ellipsis and em-dash, which are direction-free.
  final s = body.replaceAll('...', '…').replaceAll('--', '—');
  // Then quotes: walk the string and choose open vs close from context.
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '"' || c == "'") {
      final prev = i == 0 ? ' ' : s[i - 1];
      final isOpening = prev == ' ' ||
          prev == '\t' ||
          prev == '\n' ||
          prev == '(' ||
          prev == '[' ||
          prev == '{' ||
          prev == '—' ||
          prev == '…';
      if (c == '"') {
        out.write(isOpening ? '“' : '”');
      } else {
        out.write(isOpening ? '‘' : '’');
      }
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

/// Apply [smartTypography] to every line in the selected block.
SortLinesResult smartTypographyIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) smartTypography(l)],
    );

/// Inverse of [smartTypography]: convert Unicode typographic chars
/// back to ASCII. `"…"` → `"..."`, em/en dashes to `--`/`-`.
String dumbifyTypography(String body) {
  return body
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('…', '...')
      .replaceAll('—', '--')
      .replaceAll('–', '-');
}

/// Apply [dumbifyTypography] to every line in the selected block.
SortLinesResult dumbifyTypographyIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) dumbifyTypography(l)],
    );

/// Generate a random `#RRGGBB` CSS-style hex colour string. Useful
/// for design scaffolding — drop a placeholder colour into prose
/// without leaving the keyboard. Takes an optional [math.Random] so
/// tests can pin determinism via `Random(seed)`.
String generateHexColor({math.Random? random}) {
  final rng = random ?? math.Random();
  final value = rng.nextInt(0x1000000); // 24 bits.
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Format a [DateTime] as the pill-style `@YYYY-MM-DD` snippet used
/// by the `/today` slash entry. Splitting this out makes the format
/// testable without committing to a clock at the call site.
String formatTodayPill(DateTime when) {
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  return '@$yyyy-$mm-$dd';
}

/// Format a [DateTime] as the `YYYY-MM-DD HH:MM` timestamp used by
/// the `/timestamp` slash entry — sortable but separator-friendly
/// for log scribbling.
String formatTimestamp(DateTime when) {
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  final hh = when.hour.toString().padLeft(2, '0');
  final mi = when.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd $hh:$mi';
}

/// Format a [DateTime] as the ISO 8601 `YYYY-MM-DDTHH:MM:SS` form
/// used by the `/iso` slash entry. Local clock — no trailing `Z`
/// since this is wall time, not UTC.
String formatIsoDateTime(DateTime when) {
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  final hh = when.hour.toString().padLeft(2, '0');
  final mi = when.minute.toString().padLeft(2, '0');
  final ss = when.second.toString().padLeft(2, '0');
  return '$yyyy-$mm-${dd}T$hh:$mi:$ss';
}

/// Format a [DateTime] as the Unix-epoch second count used by the
/// `/epoch` slash entry. Integer-truncated.
String formatEpochTimestamp(DateTime when) =>
    (when.millisecondsSinceEpoch ~/ 1000).toString();

/// Generate a UUID v4 (random) as the canonical 36-char hyphenated
/// string. Uses [math.Random] under the hood — **not** cryptographically
/// secure (sufficient for placeholder IDs, test data, and stable
/// frontmatter keys; the user should swap to `Random.secure()` for
/// security-sensitive IDs). The version (4) and variant (8-b) nibbles
/// are forced to match RFC 4122.
String generateUuidV4({math.Random? random}) {
  final rng = random ?? math.Random();
  // Roll 16 random bytes.
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Force version 4: 0100 in the high nibble of byte 6.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Force variant RFC 4122: 10xx in the high nibbles of byte 8.
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hexByte(int b) => b.toRadixString(16).padLeft(2, '0');
  final hex = bytes.map(hexByte).join();
  // 8-4-4-4-12 grouping.
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

/// Generate a cryptographically-weak random password of [length]
/// characters drawn from a pool of upper / lower / digit / symbol
/// glyphs. The default 16-char output mixes all four classes; pass
/// a different [length] to grow / shrink it.
///
/// **Not** cryptographically secure — uses [math.Random] with a
/// system seed. Fine for placeholder passwords, throwaway secrets,
/// and test data, but the user should swap to `Random.secure()` for
/// real credentials. Kept pure-Dart so the helper can be unit-tested
/// without a widget tree.
String generatePassword({int length = 16, math.Random? random}) {
  if (length <= 0) return '';
  const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lower = 'abcdefghijklmnopqrstuvwxyz';
  const digits = '0123456789';
  const symbols = '!@#\$%^&*()-_=+[]{}<>?';
  const pool = '$upper$lower$digits$symbols';
  final rng = random ?? math.Random();
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.writeCharCode(pool.codeUnitAt(rng.nextInt(pool.length)));
  }
  return buf.toString();
}

/// Aggregate statistics about a slice of body text: words, character
/// count (without surrogate splits — counted by code-unit), and the
/// number of non-blank lines. Lightweight, pure-Dart, intentionally
/// not exposed via a class so callers can destructure into a Record.
({int words, int chars, int lines}) textStats(String body) {
  if (body.isEmpty) return (words: 0, chars: 0, lines: 0);
  // Words: split on any whitespace run, drop empties.
  final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final chars = body.length;
  // Lines: count non-empty lines (consistent with Notion's "words /
  // chars / lines" display).
  final lines = body.split('\n').where((l) => l.isNotEmpty).length;
  return (words: words, chars: chars, lines: lines);
}

/// Build a one-line human-readable stats summary like
/// `(12 words · 84 characters · 3 lines)`. Used by the slash entry
/// to insert a stats marker next to a chunk of prose.
String formatTextStats(({int words, int chars, int lines}) s) =>
    '(${s.words} words · ${s.chars} characters · ${s.lines} lines)';

/// Join every non-blank selected line into a single comma-separated
/// row. Common for converting a vertical list back into a CSV cell.
/// Whitespace around each line is trimmed so the joined output looks
/// clean. Returns the source unchanged when the block is empty.
SortLinesResult joinLinesWithCommaIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final cells =
          [for (final l in lines) l.trim()].where((l) => l.isNotEmpty).toList();
      if (cells.isEmpty) return lines;
      return [cells.join(', ')];
    });

/// Split every selected line on `,` (with optional trailing
/// whitespace) into separate lines. Inverse of [joinLinesWithCommaIn].
/// Each split cell is trimmed. Lines without a comma pass through.
SortLinesResult splitOnCommaIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final out = <String>[];
      for (final l in lines) {
        if (!l.contains(',')) {
          out.add(l);
          continue;
        }
        for (final cell in l.split(',')) {
          out.add(cell.trim());
        }
      }
      return out;
    });

/// Center every selected line within a uniform field of spaces.
/// Total width defaults to the longest line in the block. When the
/// padding can't be split evenly, the extra space goes on the right
/// — matching `padCenter` conventions in most languages. Blank lines
/// stay blank.
SortLinesResult centerLinesIn(
  String text,
  int start,
  int end, {
  int? width,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      final target = width ??
          lines.fold<int>(0, (max, l) => l.length > max ? l.length : max);
      return [
        for (final l in lines)
          if (l.isEmpty)
            l
          else if (l.length >= target)
            l
          else
            (() {
              final pad = target - l.length;
              final left = pad ~/ 2;
              final right = pad - left;
              return ' ' * left + l + ' ' * right;
            })(),
      ];
    });

/// Right-pad every selected line with spaces so all lines reach at
/// least [width] characters. Used for column alignment — when you
/// drop a list of labels next to a column of values and want them
/// to line up. Lines longer than the target are unchanged. Blank
/// lines stay blank.
SortLinesResult padRightLinesIn(
  String text,
  int start,
  int end, {
  int? width,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      final target = width ??
          lines.fold<int>(0, (max, l) => l.length > max ? l.length : max);
      return [
        for (final l in lines)
          if (l.isEmpty) l else l.padRight(target),
      ];
    });

/// Left-pad every selected line with `0` so all lines reach at
/// least [width] characters. Useful when you want a column of
/// integers to sort lexicographically the same way they sort
/// numerically (so `5` doesn't come after `50` after a string sort).
///
/// When [width] is `null` we auto-detect: pad to the longest line's
/// length in the block. Lines longer than the target width pass
/// through unchanged. Blank lines stay blank.
SortLinesResult zeroPadLinesIn(
  String text,
  int start,
  int end, {
  int? width,
}) =>
    _transformLinesIn(text, start, end, (lines) {
      final target = width ??
          lines.fold<int>(0, (max, l) => l.length > max ? l.length : max);
      return [
        for (final l in lines)
          if (l.isEmpty) l else l.padLeft(target, '0'),
      ];
    });

/// Convert every selected line that parses as a non-negative
/// decimal integer into octal (`0o…`). Negative or non-numeric
/// lines pass through.
///
///   `8`   → `0o10`
///   `64`  → `0o100`
SortLinesResult convertDecimalToOctalLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final n = int.tryParse(l.trim());
            if (n == null || n < 0) return l;
            return '0o${n.toRadixString(8)}';
          })(),
      ];
    });

/// Convert every selected line that parses as octal (`0o…` prefix)
/// into decimal. Non-octal lines are left untouched. We require the
/// `0o` prefix to distinguish from decimal — without it, `10` is
/// ambiguous (decimal 10 or octal 8?).
SortLinesResult convertOctalToDecimalLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      final octPattern = RegExp(r'^0[oO]([0-7]+)$');
      return [
        for (final l in lines)
          (() {
            final stripped = l.trim();
            final m = octPattern.firstMatch(stripped);
            if (m == null) return l;
            return int.parse(m.group(1)!, radix: 8).toString();
          })(),
      ];
    });

/// Convert every selected line that parses as a non-negative
/// decimal integer into binary (`0b…`). Negative or non-numeric
/// lines are left untouched.
///
///   `5`   → `0b101`
///   `255` → `0b11111111`
SortLinesResult convertDecimalToBinaryLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final n = int.tryParse(l.trim());
            if (n == null || n < 0) return l;
            return '0b${n.toRadixString(2)}';
          })(),
      ];
    });

/// Convert every selected line that parses as a binary value
/// (`0b1010` or bare `1010`-where-all-digits-are-0/1) into decimal.
/// Non-binary lines are left untouched. Distinguishing bare binary
/// from bare decimal is undecidable in general (the string `10` could
/// be either), so this function only converts a bare numeric line
/// when its decimal interpretation has at least 2 digits — i.e.,
/// we don't silently rewrite `10` as `2`.
SortLinesResult convertBinaryToDecimalLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      final binPattern = RegExp(r'^0[bB]([01]+)$');
      return [
        for (final l in lines)
          (() {
            final stripped = l.trim();
            final m = binPattern.firstMatch(stripped);
            if (m == null) return l;
            return int.parse(m.group(1)!, radix: 2).toString();
          })(),
      ];
    });

/// Convert every selected line that parses as a non-negative decimal
/// integer (any size) into its lowercase hex form prefixed with
/// `0x`. Non-numeric lines are left untouched.
///
///   `255`   → `0xff`
///   `0`     → `0x0`
///   `4096`  → `0x1000`
SortLinesResult convertDecimalToHexLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final n = int.tryParse(l.trim());
            if (n == null || n < 0) return l;
            return '0x${n.toRadixString(16)}';
          })(),
      ];
    });

/// Convert every selected line that parses as a hex value
/// (`0x` prefix, or bare `[0-9a-fA-F]+`) into its decimal form.
/// Non-hex lines are left untouched.
SortLinesResult convertHexToDecimalLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      final hexPattern = RegExp(r'^(0[xX])?([0-9a-fA-F]+)$');
      return [
        for (final l in lines)
          (() {
            final stripped = l.trim();
            final m = hexPattern.firstMatch(stripped);
            if (m == null) return l;
            // Reject bare-non-0x patterns that are just decimal digits
            // (e.g. "42") — without the 0x prefix, treat them as ASCII
            // decimal and leave them alone.
            if (m.group(1) == null && !RegExp(r'[a-fA-F]').hasMatch(stripped)) {
              return l;
            }
            final n = int.parse(m.group(2)!, radix: 16);
            return n.toString();
          })(),
      ];
    });

/// Convert a positive decimal integer (1..3999) into its Roman
/// numeral representation. Returns the empty string when out of
/// range. Exposed for testing; production callers go through
/// [convertDecimalToRomanLinesIn].
String decimalToRoman(int n) {
  if (n < 1 || n > 3999) return '';
  const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const syms = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
  final buf = StringBuffer();
  var rem = n;
  for (var i = 0; i < vals.length; i++) {
    while (rem >= vals[i]) {
      buf.write(syms[i]);
      rem -= vals[i];
    }
  }
  return buf.toString();
}

/// Convert a Roman-numeral string into its decimal value. Returns
/// `null` for the empty string and for any input containing a
/// non-Roman character. Accepts mixed case.
int? romanToDecimal(String roman) {
  if (roman.isEmpty) return null;
  const map = {
    'I': 1, 'V': 5, 'X': 10, 'L': 50,
    'C': 100, 'D': 500, 'M': 1000,
  };
  final upper = roman.toUpperCase();
  var total = 0;
  for (var i = 0; i < upper.length; i++) {
    final v = map[upper[i]];
    if (v == null) return null;
    final next = i + 1 < upper.length ? map[upper[i + 1]] : null;
    if (next != null && next > v) {
      total += next - v;
      i++;
    } else {
      total += v;
    }
  }
  return total;
}

/// Convert every selected line that parses as a decimal integer
/// (1..3999) into its Roman numeral form. Non-numeric lines are
/// left untouched.
SortLinesResult convertDecimalToRomanLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final n = int.tryParse(l.trim());
            if (n == null || n < 1 || n > 3999) return l;
            return decimalToRoman(n);
          })(),
      ];
    });

/// Convert every selected line that parses as a Roman numeral into
/// its decimal form. Non-Roman lines stay untouched.
SortLinesResult convertRomanToDecimalLinesIn(
  String text,
  int start,
  int end,
) =>
    _transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final stripped = l.trim();
            if (stripped.isEmpty) return l;
            final d = romanToDecimal(stripped);
            return d == null ? l : d.toString();
          })(),
      ];
    });

/// Convert each run of [width] **leading** spaces on every selected
/// line into a single tab character. Trailing/inline spaces are
/// left alone — only the indent is converted, mirroring the
/// VS Code / Vim convention. Defaults to 2-space indents.
///
/// This is the inverse of [tabsToSpacesIn] for indents only: a round
/// trip preserves leading-tab-only files, and a file with mixed
/// inline spaces stays unchanged on the trip back.
SortLinesResult spacesToTabsIn(String text, int start, int end, {int width = 2}) {
  return _transformLinesIn(
    text,
    start,
    end,
    (lines) => [
      for (final l in lines)
        (() {
          // Find the run of leading spaces.
          var i = 0;
          while (i < l.length && l.codeUnitAt(i) == 0x20) {
            i++;
          }
          final tabs = '\t' * (i ~/ width);
          final leftover = ' ' * (i % width);
          return '$tabs$leftover${l.substring(i)}';
        })(),
    ],
  );
}

/// Uppercase every line in the selected block. Common power-user
/// transform; mirrors VS Code's "Transform to Uppercase".
SortLinesResult uppercaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) l.toUpperCase()],
    );

/// Lowercase every line in the selected block.
SortLinesResult lowercaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) l.toLowerCase()],
    );

/// Toggle the case of every cased character on every selected line:
/// uppercase becomes lowercase and vice versa, character-by-character.
/// Non-cased characters (digits, punctuation, whitespace, symbols, and
/// most non-Latin scripts) pass through. Mirrors Notepad++'s "Invert
/// case" and JetBrains' "Toggle case" — running the op twice is the
/// identity for ASCII inputs.
///
///   "Hello World"  →  "hELLO wORLD"
SortLinesResult swapCaseLinesIn(String text, int start, int end) =>
    _transformLinesIn(
      text, start, end, (lines) => [
        for (final l in lines)
          (() {
            final buf = StringBuffer();
            for (final c in l.split('')) {
              final lo = c.toLowerCase();
              final up = c.toUpperCase();
              if (c == lo && c != up) {
                buf.write(up); // was lowercase
              } else if (c == up && c != lo) {
                buf.write(lo); // was uppercase
              } else {
                buf.write(c); // not cased — digit / symbol / etc.
              }
            }
            return buf.toString();
          })(),
      ],
    );

/// Toggle a `- ` bullet prefix on every line in the selected block.
///
/// The toggle is idempotent in pairs: if **every** non-empty line in the
/// block already starts with `- ` (allowing the standard leading-indent
/// pattern `  - `), the prefix is **stripped** from every line. Otherwise
/// the prefix is **added** to every non-empty line. Blank lines stay
/// blank in both directions. Existing leading indentation is preserved
/// — `  foo` becomes `  - foo`.
///
/// Mirrors the Notion / VS Code "toggle bullet" gesture.
SortLinesResult toggleBulletPrefixIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      bool startsWithBullet(String l) {
        final stripped = l.trimLeft();
        return stripped.startsWith('- ');
      }

      final nonEmpty = [for (final l in lines) if (l.trim().isNotEmpty) l];
      final allBulleted =
          nonEmpty.isNotEmpty && nonEmpty.every(startsWithBullet);

      return [
        for (final l in lines)
          if (l.trim().isEmpty)
            l
          else if (allBulleted)
            // Strip the bullet, preserving leading indent.
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              final after = l.trimLeft().substring(2); // drop "- "
              return '$indent$after';
            })()
          else if (startsWithBullet(l))
            l
          else
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              return '$indent- ${l.trimLeft()}';
            })(),
      ];
    });

/// Toggle a `- [ ] ` task-list prefix on every line in the selected
/// block.
///
/// Behaviour mirrors [toggleBulletPrefixIn]: if every non-empty line
/// already starts with a task checkbox (`- [ ]` or `- [x]`, allowing
/// leading indent), the prefix is stripped to expose the inner text.
/// Otherwise every non-empty line gains a `- [ ] ` checkbox. The
/// `[x]`/`[X]` (checked) form is recognised on strip but always
/// re-added as unchecked `[ ]`, since the user's intent on "toggle on"
/// is "make these tasks I haven't started yet".
SortLinesResult toggleTaskPrefixIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final taskPattern = RegExp(r'^- \[[ xX]\] ');
      bool startsWithTask(String l) => taskPattern.hasMatch(l.trimLeft());

      final nonEmpty = [for (final l in lines) if (l.trim().isNotEmpty) l];
      final allTasked =
          nonEmpty.isNotEmpty && nonEmpty.every(startsWithTask);

      return [
        for (final l in lines)
          if (l.trim().isEmpty)
            l
          else if (allTasked)
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              // Drop the matched "- [.] " prefix (6 chars).
              final after = l.trimLeft().substring(6);
              return '$indent$after';
            })()
          else if (startsWithTask(l))
            l
          else
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              return '$indent- [ ] ${l.trimLeft()}';
            })(),
      ];
    });

/// Re-number every selected line that already starts with `N. `
/// so the block reads 1, 2, 3, … sequentially from the top. Non-
/// numbered lines pass through. Useful after inserting / deleting
/// items mid-list to fix the numbering without doing two
/// toggleNumberedPrefixIn passes (which would touch every line).
SortLinesResult renumberListLinesIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final numPattern = RegExp(r'^(\s*)\d+\. (.*)$');
      var n = 1;
      return [
        for (final l in lines)
          (() {
            final m = numPattern.firstMatch(l);
            if (m == null) return l;
            final indent = m.group(1) ?? '';
            final body = m.group(2) ?? '';
            return '$indent${n++}. $body';
          })(),
      ];
    });

/// Toggle a `N. ` numbered-list prefix on every line in the selected
/// block.
///
/// Differs from [toggleBulletPrefixIn] in that adding the prefix
/// **renumbers** every non-empty line from 1 — the user's intent is a
/// single ordered list, not an alternating count. Stripping recognises
/// any `\d+\. ` prefix (allowing leading indent). Blank lines and
/// existing indentation are preserved in both directions.
SortLinesResult toggleNumberedPrefixIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      final numPattern = RegExp(r'^\d+\. ');
      bool startsWithNumber(String l) => numPattern.hasMatch(l.trimLeft());

      final nonEmpty = [for (final l in lines) if (l.trim().isNotEmpty) l];
      final allNumbered =
          nonEmpty.isNotEmpty && nonEmpty.every(startsWithNumber);

      final out = <String>[];
      var n = 1;
      for (final l in lines) {
        if (l.trim().isEmpty) {
          out.add(l);
          continue;
        }
        final indent = l.substring(0, l.length - l.trimLeft().length);
        final body = l.trimLeft();
        if (allNumbered) {
          // Strip "<digits>. " prefix.
          final m = numPattern.firstMatch(body);
          out.add('$indent${body.substring(m!.end)}');
        } else if (startsWithNumber(l)) {
          // Re-number this line so the whole block reads 1,2,3,…
          final m = numPattern.firstMatch(body);
          out.add('$indent$n. ${body.substring(m!.end)}');
          n++;
        } else {
          out.add('$indent$n. $body');
          n++;
        }
      }
      return out;
    });

/// Toggle a `> ` blockquote prefix on every line in the selected
/// block.
///
/// Behaviour mirrors [toggleBulletPrefixIn]: when every non-empty
/// line already starts with `> ` (allowing leading indent), the
/// prefix is stripped. Otherwise every non-empty line gains it.
/// Existing indent is preserved.
///
/// Recognises the exact `> ` prefix only — a `>> nested` line is
/// treated as plain text and gains one more `> ` (becoming
/// `> >> nested`), so repeated toggles let the user step nested
/// quotes outward one level at a time on reapply.
SortLinesResult toggleBlockquotePrefixIn(String text, int start, int end) =>
    _transformLinesIn(text, start, end, (lines) {
      bool startsWithQuote(String l) => l.trimLeft().startsWith('> ');

      final nonEmpty = [for (final l in lines) if (l.trim().isNotEmpty) l];
      final allQuoted =
          nonEmpty.isNotEmpty && nonEmpty.every(startsWithQuote);

      return [
        for (final l in lines)
          if (l.trim().isEmpty)
            l
          else if (allQuoted)
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              final after = l.trimLeft().substring(2);
              return '$indent$after';
            })()
          else if (startsWithQuote(l))
            l
          else
            (() {
              final indent = l.substring(0, l.length - l.trimLeft().length);
              return '$indent> ${l.trimLeft()}';
            })(),
      ];
    });

/// Sentence-case every line in the selected block: lowercase the
/// whole line, then capitalise the first alphabetic character of
/// each sentence. Sentence boundaries are the start of a line plus
/// any `.`, `!`, or `?` followed by whitespace. Pronoun `i` and
/// contractions starting with `i'` are re-capitalised. Mirrors the
/// VS Code / Notion "transform to sentence case" gesture.
SortLinesResult sentenceCaseLinesIn(String text, int start, int end) {
  String sentenceCase(String line) {
    final lower = line.toLowerCase();
    final out = StringBuffer();
    var capitaliseNext = true;
    for (var i = 0; i < lower.length; i++) {
      final c = lower.codeUnitAt(i);
      final isAlpha = c >= 0x61 && c <= 0x7a;
      if (isAlpha && capitaliseNext) {
        out.writeCharCode(c - 0x20);
        capitaliseNext = false;
      } else {
        out.writeCharCode(c);
        if (c == 0x2e /* . */ || c == 0x21 /* ! */ || c == 0x3f /* ? */) {
          capitaliseNext = true; // Will fire on the next non-space alpha.
        } else if (isAlpha || (c >= 0x30 && c <= 0x39)) {
          capitaliseNext = false;
        }
      }
    }
    // Re-capitalise pronoun "I" / contractions like "i'm", "i've".
    return out.toString().replaceAllMapped(
          RegExp(r"(^|[^a-z])i(?=$|[^a-z])"),
          (m) => '${m[1]}I',
        );
  }

  return _transformLinesIn(
    text,
    start,
    end,
    (lines) => [for (final l in lines) sentenceCase(l)],
  );
}

/// Title-case every line in the selected block: capitalise the first
/// letter of each whitespace-separated word, lowercase the rest. Words
/// shorter than 4 chars in the middle of a line (and, or, the, of, …)
/// stay lowercased — the standard English-title heuristic. The first
/// and last word of a line are always capitalised regardless of length.
SortLinesResult titleCaseLinesIn(String text, int start, int end) {
  String titleCaseLine(String line) {
    const small = {
      'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of',
      'on', 'or', 'so', 'the', 'to', 'up', 'yet', 'vs', 'via', 'per',
    };
    final words = line.split(' ');
    if (words.isEmpty) return line;
    final buf = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (i > 0) buf.write(' ');
      final w = words[i];
      if (w.isEmpty) continue;
      final lower = w.toLowerCase();
      final isEdge = i == 0 || i == words.length - 1;
      if (!isEdge && small.contains(lower)) {
        buf.write(lower);
      } else {
        buf.write(w.substring(0, 1).toUpperCase() + lower.substring(1));
      }
    }
    return buf.toString();
  }

  return _transformLinesIn(
    text, start, end, (lines) => [for (final l in lines) titleCaseLine(l)],
  );
}
