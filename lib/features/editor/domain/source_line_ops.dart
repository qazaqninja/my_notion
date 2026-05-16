/// Pure transformations on a (text, caret-offset) pair for the
/// source-mode editor. Kept dependency-free so the logic can be
/// unit-tested without a widget tree.
///
/// The "make this paste plain" cleanup family
/// (`stripMarkdownEmphasisLinesIn`, `stripMarkdownLinksLinesIn`,
/// `stripHtmlTagsLinesIn`, `stripLeadingNumberPrefixIn`) lives in
/// `text_cleanup_ops.dart` and is re-exported from here so existing
/// callers don't need to know about the split (M983).
library;

import 'dart:convert';
import 'dart:math' as math;

export 'text_cleanup_ops.dart';
export 'text_scaffolds.dart';

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
SortLinesResult transformLinesIn(
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
    transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return sorted;
    });

/// Sort the lines that the selection touches in **descending** order
/// (Z→A, case-insensitive). Selection-widening rules and result shape
/// mirror [sortLinesIn]; this is the natural companion for flipping
/// a previously-ascending block without an extra reverse step.
SortLinesResult sortLinesDescIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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

/// Sort the lines touched by the selection by the **last signed
/// number** that appears anywhere in each line, ascending. Symmetric
/// with [sortLinesByFirstNumberIn] (M970) but anchors at the right
/// edge — useful for log lines that end with a count / duration /
/// timestamp, or for value-then-label rows where the number is the
/// last token (`alice scored 87`). Lines with no number sort to the
/// bottom in original order.
SortLinesResult sortLinesByLastNumberIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        final all = re.allMatches(l).toList();
        final last = all.isEmpty ? null : all.last;
        final v = last == null ? null : double.tryParse(last.group(0)!);
        if (v == null) {
          nonNumeric.add(l);
        } else {
          numeric.add((v, l));
        }
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Extract every Quill wikilink (`[[ULID]]` / `[[ULID#anchor]]` /
/// `[[ULID|alias]]` / `![[ULID]]`) from each selected line and
/// emit them one-per-line WITHOUT the wrapping brackets. Useful
/// for surveying which pages a prose paste-in references ahead of
/// migrating them into a frontmatter relation field.
///
/// Recognition: 26-char ULID (`[0-9A-Z]{26}`), the canonical
/// Quill page identifier, optionally followed by `#anchor-slug` or
/// `|alias` before the closing `]]`. The leading `!` for
/// transcludes is consumed as part of the match so the output
/// still surfaces the page reference.
SortLinesResult extractWikilinksFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // The body capture group keeps the ULID + optional anchor /
      // alias as a single string — same shape the renderer accepts.
      final re = RegExp(
        r'!?\[\[([0-9A-Z]{26}(?:#[a-z0-9][a-z0-9\-]*)?(?:\|[^\]\n]*)?)\]\]',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every `@mention` from each selected line and emit them
/// one-per-line WITHOUT the leading `@`. Useful for harvesting
/// inline-written attendee / DRI mentions out of meeting notes,
/// retro action items, or any prose where the user wants a
/// flat list of "who got mentioned".
///
/// Recognition: `@` immediately followed by a letter (so `@alice`
/// and `@bob.smith` count, but `email@x.test` does NOT — the
/// negative lookbehind on alphanumeric rejects the `@` inside an
/// email address). Mention body accepts letters / digits / `.` /
/// `-` / `_`.
SortLinesResult extractMentionsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<![A-Za-z0-9])@([A-Za-z][\w.\-]*)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every `#hashtag` from each selected line and emit them
/// one-per-line WITHOUT the leading `#`. Useful for harvesting
/// inline-written tags out of prose for migration into the
/// frontmatter `tags:` list, or for surveying which tags appear in
/// a paste-in.
///
/// Recognition: `#` immediately followed by a letter/digit (so the
/// `#` in `#1` and `#header` both count, but `# heading` does not).
/// Hashtag continues through letters / digits / `-` / `_`. Trailing
/// punctuation drops out cleanly: `#urgent.` → `urgent`.
SortLinesResult extractHashtagsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Anchored on word boundary so `email#cc:` doesn't yield `cc`.
      final re = RegExp(r'(?<![A-Za-z0-9])#([A-Za-z0-9][\w\-]*)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every http/https/ftp URL from each selected line and emit
/// them one-per-line. Useful for harvesting links from prose
/// paste-ins ahead of bulk-bookmarking or building a links-only
/// reference list.
///
/// Distinct from M977 `stripMarkdownLinksLines` (which UNWRAPS
/// `[label](url)` markdown to keep the label) and M1011
/// `removeUrlsLines` (which DROPS bare URLs from prose). This op
/// KEEPS only the URLs themselves, dropping everything else.
SortLinesResult extractUrlsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?:https?|ftp)://\S+');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every email-shaped substring from each selected line and
/// emit them one-per-line in original order. Useful for bulk-pulling
/// contact addresses out of prose / paste-ins where the user wants
/// just the addresses ahead of dedupe / sort / CSV-import.
///
/// Recognition: `local@domain.tld` with the standard URL-safe
/// `local` characters and a 2+ character TLD. Lines without an
/// email pass through silently (dropped from the output) — same
/// convention as [extractNumbersFromLinesIn].
SortLinesResult extractEmailsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // RFC 5322 in full is genuinely awful; this approximation
      // covers the 99% case that's interesting at vault scale.
      final re = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every signed-decimal number from each selected line and
/// emit them one-per-line in original order. Useful for pulling a
/// numeric column out of tabular prose (`alice scored 87` →
/// `87`) ahead of running a stats op on the result.
///
/// Lines without numbers are dropped from the output (rather than
/// emitting an empty line) — the gesture is "give me the numbers,
/// not the rows".
SortLinesResult extractNumbersFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Sort the lines touched by the selection by the **median** of all
/// numbers in each line, ascending. Useful for outlier-resistant
/// ranking: a row with one anomalous value won't skew its position
/// the way `sortLinesByMaxNumber` or `sortLinesBySumOfNumbers` would.
/// Lines with no number drop to the bottom in original order — same
/// convention as the rest of the per-row numeric-sort family.
SortLinesResult sortLinesByMedianNumberIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        final values = <double>[
          for (final m in re.allMatches(l))
            if (double.tryParse(m.group(0)!) case final v?) v,
        ]..sort();
        if (values.isEmpty) {
          nonNumeric.add(l);
          continue;
        }
        final mid = values.length ~/ 2;
        final med = values.length.isOdd
            ? values[mid]
            : (values[mid - 1] + values[mid]) / 2;
        numeric.add((med, l));
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Sort the lines touched by the selection by the **smallest signed
/// number** that appears anywhere in each line, ascending. Mirror of
/// [sortLinesByMaxNumberIn] — picks the per-row trough rather than
/// the peak. Useful for rows where the worst-case value carries the
/// meaning (`min latency`, `low-water-mark`, `floor price`).
SortLinesResult sortLinesByMinNumberIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        double? minVal;
        for (final m in re.allMatches(l)) {
          final v = double.tryParse(m.group(0)!);
          if (v == null) continue;
          if (minVal == null || v < minVal) minVal = v;
        }
        if (minVal == null) {
          nonNumeric.add(l);
        } else {
          numeric.add((minVal, l));
        }
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Sort the lines touched by the selection by the **largest signed
/// number** that appears anywhere in each line, ascending. Useful
/// when each row has multiple numbers and the peak (e.g. "max load",
/// "highest score") carries the meaning. Lines with no number drop
/// to the bottom in original order — same convention as the rest of
/// the numeric-sort family (M970 / M1042 / M1043).
SortLinesResult sortLinesByMaxNumberIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      final numeric = <(double, String)>[];
      final nonNumeric = <String>[];
      for (final l in lines) {
        double? maxVal;
        for (final m in re.allMatches(l)) {
          final v = double.tryParse(m.group(0)!);
          if (v == null) continue;
          if (maxVal == null || v > maxVal) maxVal = v;
        }
        if (maxVal == null) {
          nonNumeric.add(l);
        } else {
          numeric.add((maxVal, l));
        }
      }
      numeric.sort((a, b) => a.$1.compareTo(b.$1));
      return [...numeric.map((p) => p.$2), ...nonNumeric];
    });

/// Sort the lines touched by the selection by the **sum of every
/// signed number** found anywhere in each line, ascending. Useful
/// for ranking tabular rows where the per-row total is the metric
/// (`alice 10 20 30` outsorts `bob 5 5 5` on the sum 60 vs 15).
/// Lines with no number contribute 0 and sort accordingly; ties are
/// broken by original input order.
SortLinesResult sortLinesBySumOfNumbersIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'-?\d+(?:\.\d+)?');
      double sumLine(String l) {
        var total = 0.0;
        for (final m in re.allMatches(l)) {
          final v = double.tryParse(m.group(0)!);
          if (v != null) total += v;
        }
        return total;
      }
      // Decorate-sort-undecorate so the comparator stays cheap.
      final decorated = [
        for (final l in lines) (sumLine(l), l),
      ];
      // `compareTo` on `double` is stable for our purposes — same key
      // means equal in the sort, and `List.sort` is stable in Dart.
      decorated.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final p in decorated) p.$2];
    });

/// Sort the lines touched by the selection by **word count**
/// ascending (fewest words first). Words are whitespace-separated
/// non-empty runs, matching the convention from `countLinesIn` and
/// the text-stats footer. Equal-count lines fall back to a stable
/// case-insensitive lex compare so output is deterministic. Useful
/// for prioritising a bullet list by terseness, or surfacing
/// one-word labels at the top of a paste-in.
SortLinesResult sortLinesByWordCountIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      final sorted = [...lines]..sort(compareNatural);
      return sorted;
    });

/// Extract every markdown-link URL (`[label](url)` → `url`) from
/// each selected line. Companion to
/// [extractMarkdownLinkLabelsFromLinesIn] (M1068) — labels vs URLs
/// are the two halves of every markdown link.
///
/// Different from [extractUrlsFromLinesIn] (M1054) which catches
/// bare URLs anywhere in prose; this one ONLY pulls URLs that are
/// wrapped in markdown link syntax. A mixed paste-in (some bare,
/// some wrapped) needs both extractors to capture every link.
SortLinesResult extractMarkdownLinkUrlsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<!\[)\[[^\]\n]+\]\(([^)\n]*)\)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every markdown-link LABEL (`[label](url)` → `label`) from
/// each selected line. Useful for harvesting click-text out of
/// reference paste-ins — "what was each link called?" — without
/// the URLs themselves.
///
/// Negative lookbehind on `[` rejects the `[[...]]` wikilink form
/// so a Quill-internal relation doesn't fall into this extractor's
/// pool (use [extractWikilinksFromLinesIn] for that).
SortLinesResult extractMarkdownLinkLabelsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<!\[)\[([^\]\n]+)\]\([^)\n]*\)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every markdown-IMAGE URL (`![alt](url)` → `url`) from
/// each selected line. Parallel to
/// [extractMarkdownLinkUrlsFromLinesIn] (M1066) but specifically
/// requires the leading `!` that marks an image — bare
/// `[label](url)` text does NOT match here.
///
/// Use this when you specifically want image references (an
/// attachment manifest, a CDN audit, a broken-image sweep) rather
/// than every link on the page.
///
/// Empty alt text (`![](url)`) IS supported — the regex uses
/// `*` (zero-or-more) rather than `+` for the alt slot, since
/// CommonMark allows an empty alt and it's a common pattern for
/// purely decorative images.
SortLinesResult extractMarkdownImageUrlsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'!\[[^\]\n]*\]\(([^)\n]*)\)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every markdown-IMAGE ALT text (`![alt](url)` → `alt`)
/// from each selected line. Companion to
/// [extractMarkdownImageUrlsFromLinesIn] — alts vs URLs are the
/// two halves of every image reference.
///
/// Useful for harvesting caption / accessibility strings without
/// the underlying URLs. Empty alts emit as empty strings (one
/// blank line per match) since `*` matches zero characters;
/// pipe through a drop-empty-lines pass if you only want
/// non-blank captions.
SortLinesResult extractMarkdownImageAltsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'!\[([^\]\n]*)\]\([^)\n]*\)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every UUID-shaped substring from each selected line
/// (`8-4-4-4-12` hex format, case-insensitive). Useful for pulling
/// generated identifiers out of logs / debug paste-ins ahead of
/// dedupe / sort / cross-reference lookups.
///
/// Recognition: 8 hex + `-` + 4 + `-` + 4 + `-` + 4 + `-` + 12, with
/// `\b` boundaries on each end so embedded runs in longer hex
/// strings don't match.
SortLinesResult extractUuidsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every semver-shaped version string from each selected
/// line (`MAJOR.MINOR.PATCH` with optional `-PRERELEASE` and
/// `+BUILD` metadata, per semver.org/2.0.0). Useful for scraping
/// changelogs, `pubspec.yaml`/`package.json` paste-ins, and
/// release-tag dumps.
///
/// Strict-ish recognition:
/// - All three numeric segments are required (`1.2` won't match).
/// - No leading zeros in MAJOR/MINOR/PATCH (`01.2.3` rejected).
/// - Pre-release / build identifiers are `[0-9A-Za-z-]+` segments
///   joined by dots (so `1.2.3-rc.1+build.abc-def` matches).
/// - Negative lookahead `(?!\.\d)` after PATCH rejects 4-segment
///   versions like `1.2.3.4` so a partial match isn't returned.
/// - An optional `v` immediately before the major is accepted and
///   INCLUDED in the match (`v1.2.3` is the dominant changelog /
///   Git-tag form and dropping it loses the tag's identity). The
///   leading position must be preceded by a non-word, non-`.`
///   char (or start-of-line) so `foo1.2.3` does NOT match.
///
/// Distinct from [extractNumbersFromLinesIn] (M1052) which catches
/// any integer/decimal anywhere; this one ONLY emits well-formed
/// semvers — making it safe to pipe into a dependency-update
/// audit or release-grep without filtering noise.
SortLinesResult extractSemverFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?<![\w.])v?(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)'
        r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
        r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
        r'(?!\.\d)\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every MAC-address-shaped substring from each selected
/// line. Recognises the two common forms:
///   - Colon-separated:  `01:23:45:67:89:AB`
///   - Hyphen-separated: `01-23-45-67-89-AB`
/// Both forms accept upper / lower / mixed-case hex digits. The
/// separator is captured and back-referenced, so mixed forms like
/// `01:23-45:67:89:AB` do NOT match — only same-separator runs
/// pass.
///
/// Useful for triaging network log paste-ins, DHCP leases, ARP
/// tables, and switch port dumps. Distinct from
/// [extractIpv4FromLinesIn] (M1064 — dotted-quad IP) and
/// [extractUuidsFromLinesIn] (M1069 — UUID 8-4-4-4-12 form).
SortLinesResult extractMacAddressesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Backref `\1` forces the same separator throughout the
      // run so `01:23-45:67:89:AB` doesn't pass.
      final re = RegExp(
        r'\b[0-9a-fA-F]{2}([:-])'
        r'(?:[0-9a-fA-F]{2}\1){4}'
        r'[0-9a-fA-F]{2}\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every backtick-delimited inline code span
/// (`` `foo` `` → `foo`) from each selected line. Useful for
/// pulling identifier mentions out of prose — code-review
/// comments, design docs, API summaries — without the
/// surrounding narrative.
///
/// Single-backtick form only (the dominant case for inline
/// code). Multi-backtick delimiters (CommonMark allows
/// `` ``foo`` `` for spans containing a literal backtick)
/// are not supported in v1 — those land in the leftover
/// prose and are skipped.
///
/// The regex requires at least one non-backtick, non-newline
/// char between the delimiters, so empty `` `` `` does NOT
/// match (it isn't a meaningful code span). Distinct from
/// [extractMarkdownLinkLabelsFromLinesIn] (M1068 link labels)
/// and [extractMarkdownImageAltsFromLinesIn] (M1073 image alts)
/// — different markdown surfaces, different transforms.
SortLinesResult extractMarkdownCodeSpansFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'`([^`\n]+)`');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the title text from every ATX-style markdown heading
/// (`# H1`, `## H2`, … `###### H6`) on each selected line.
/// Useful for TOC generation, slug audits, and "give me just
/// the titles" prose extraction.
///
/// Strict-ish recognition:
/// - 1 to 6 leading `#` chars (CommonMark caps the level at 6).
/// - At least one whitespace char separates the hashes from
///   the title (so `#NoSpace` is NOT a heading).
/// - Hashes must be at line start (no leading indentation).
/// - ATX-closed form (`## Title ##`) IS supported — trailing
///   `#`s and surrounding whitespace are stripped.
/// - Setext underline form (`Title\n=====`) is NOT recognised:
///   this extractor only sees one line at a time, so cross-
///   line shapes are out of scope.
///
/// Title content captured as-is (no inline-markdown unwrapping)
/// — pipe through [extractMarkdownCodeSpansFromLinesIn] or
/// strip-emphasis transforms downstream if needed.
SortLinesResult extractMarkdownHeadingsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `(.+?)` non-greedy so the trailing `\s*#*\s*$` claim
      // gets a chance to eat the closed-form trailing hashes.
      final re = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(2)!);
      }
      return out;
    });

/// Extract the quoted content from every markdown blockquote
/// line (`> quoted text` → `quoted text`). Useful for harvesting
/// cited material from review docs, threading apps, and editor
/// paste-ins.
///
/// Recognition:
/// - One or more leading `>` chars at line start (no indent).
/// - Optional single whitespace separator (so `>nospace` works).
/// - At least one content char captured after — bare `>` and
///   `> ` (marker without content) do NOT match.
///
/// Greedy `>+` flattens runs of contiguous `>` markers in a
/// single pass, so `>>> deep` emits `deep`. The space-separated
/// CommonMark nested form `> > inner` only unwraps one level
/// per pass: a first pass yields `> inner`, a second yields
/// `inner`. Chain the transform if full flattening is desired.
SortLinesResult extractMarkdownBlockquoteContentFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'^>+\s?(.+)$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract the item content from every markdown list line
/// (unordered `- foo` / `* foo` / `+ foo`, or ordered `1. foo`).
/// Useful for "give me just the points without the markers" —
/// flattening an outline into a plain bullet-list of strings,
/// feeding items into a downstream search or sort, etc.
///
/// Recognition:
/// - Optional leading whitespace (so indented sub-items in an
///   outline still match — this is the dominant Notion-style
///   list shape).
/// - One of the unordered markers `-`, `*`, `+` OR an ordered
///   marker `N.` for any non-negative integer `N`.
/// - At least one whitespace separates marker from content.
/// - At least one content char is required (bare `-` does NOT
///   match).
///
/// Distinct from heading / blockquote extractors — different
/// markdown surfaces, different transforms. 21st member of
/// the extraction family.
SortLinesResult extractMarkdownListContentFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+(.+)$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract the content of every GFM strikethrough span
/// (`~~struck~~` → `struck`) from each selected line. Useful
/// for harvesting crossed-off / superseded items from a doc
/// — meeting notes where decisions changed, design pivots,
/// reverted action items.
///
/// Recognition:
/// - Exact double tilde `~~` on both sides (GFM rule). Single
///   tildes are NOT matched.
/// - At least one non-tilde, non-newline char between (so
///   `~~~~` zero-content span does NOT match).
/// - Span never crosses a newline (the `[^~\n]+` class
///   excludes `\n`).
///
/// 22nd member of the extraction family. Distinct from code
/// spans (M1077, backtick-delimited) and emphasis (a future
/// `**bold**` / `*italic*` extractor) — different markdown
/// surfaces.
SortLinesResult extractMarkdownStrikethroughFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'~~([^~\n]+)~~');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the language hint from every markdown fenced-code
/// opener (`` ```dart `` → `dart`) on each selected line.
/// Useful for surveying which languages a doc covers, polyglot
/// snippet counting, and audits like "do all my Python blocks
/// say `python` and not `py`?".
///
/// Recognition:
/// - Optional leading whitespace (CommonMark allows up to 3
///   spaces of indent before a fence).
/// - Three or more backticks (CM requires `>=3`).
/// - Optional whitespace between the fence and the lang.
/// - At least one lang-identifier char captured. The class
///   `[\w+\-.#]+` covers `dart`, `c++`, `c#`, `objective-c`,
///   `python3`, `node.js` — the realistic alphabet for code-
///   fence language hints.
///
/// The closing fence (`` ``` `` alone, no lang) does NOT
/// match — the regex requires at least one lang char. Tilde
/// fences (`~~~lang`) are out of scope for v1 since backtick
/// is the dominant form.
///
/// 23rd member of the extraction family.
SortLinesResult extractMarkdownCodeFenceLangsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'^\s*`{3,}\s*([\w+\-.#]+)');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract the content of every markdown bold span
/// (`**foo**` or `__foo__` → `foo`) from each selected line.
/// Useful for surveying which terms are emphasized in a doc —
/// glossary harvest, term-frequency audit, etc.
///
/// Recognition (both forms supported):
/// - `**…**`: two asterisks on each side.
/// - `__…__`: two underscores on each side.
/// At least one non-delimiter, non-newline char between the
/// pair (so `****` and `____` zero-content runs do NOT match).
/// Spans never cross a newline.
///
/// Single-delimiter italic (`*foo*` / `_foo_`) is deliberately
/// NOT matched here — a future milestone will add the italic
/// variant. `***bold-italic***` is captured as a bold span
/// whose content includes the wrapped italic markers; chain
/// the italic extractor when it ships if you want both.
///
/// 24th member of the extraction family.
SortLinesResult extractMarkdownBoldFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Two alternations — asterisk form OR underscore form.
      // Each captures its own group; the non-null one wins.
      final re = RegExp(r'\*\*([^*\n]+)\*\*|__([^_\n]+)__');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add((m.group(1) ?? m.group(2))!);
        }
      }
      return out;
    });

/// Extract the content of every markdown single-delimiter italic
/// span (`*foo*` or `_foo_` → `foo`) from each selected line.
/// Natural companion to [extractMarkdownBoldFromLinesIn] (M1084,
/// the doubled-delimiter form).
///
/// Recognition (both forms supported):
/// - `*…*`: single asterisks, neither flanked by another `*`.
/// - `_…_`: single underscores, neither flanked by another `_`.
/// The lookbehind / lookahead guards `(?<!\*)…(?!\*)` (and
/// `_` variant) ensure the doubled-delimiter bold form is NOT
/// captured by accident.
///
/// `***bold italic***` produces NO match here — every `*` is
/// flanked by another `*`, so the italic regex rejects all
/// positions. Use the bold extractor instead, which captures
/// the inner content as a single bold span.
///
/// 25th member of the extraction family. The emphasis pair
/// (bold M1084 + italic M1085) is now complete; chain both
/// transforms when both gestures need to be harvested.
SortLinesResult extractMarkdownItalicFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add((m.group(1) ?? m.group(2))!);
        }
      }
      return out;
    });

/// Extract every markdown footnote ID (`[^id]` → `id`) from each
/// selected line. Useful for footnote audits: pulling every
/// footnote ID a doc references / defines, so you can compare
/// the two sets (orphan defs, missing refs, duplicate IDs).
///
/// Captures BOTH reference shapes equivalently:
/// - In-prose ref `… see [^1]` → `1`
/// - Definition-line head `[^1]: text` → `1`
///
/// The transform is "extract footnote IDs" rather than "extract
/// refs OR defs separately" because both surfaces share the
/// `[\^id\]` shape; a downstream sort+uniq counts each ID's
/// total occurrences (a ref + a def = count 2; an orphan = 1).
///
/// Recognition:
/// - Literal `[^` opener.
/// - At least one non-`]`, non-newline ID char captured.
/// - Literal `]` closer.
///
/// 26th member of the extraction family.
SortLinesResult extractMarkdownFootnoteIdsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\[\^([^\]\n]+)\]');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the body text from every markdown footnote
/// DEFINITION line on each selected line (`[^id]: text` →
/// `text`). Companion to M1086's footnote-ID extractor —
/// pair them to get `(id, body)` tuples for analysis,
/// glossary export, or footnote-content audits.
///
/// Recognition: `^\s*\[\^[^\]\n]+\]:\s+(.+)$`
/// - Optional leading whitespace.
/// - `[^id]` opener (any non-`]`, non-newline id chars).
/// - Literal `:` then at least one whitespace.
/// - Body content captured (at least one char).
///
/// In-prose footnote REFERENCES (`see [^1]`) are NOT matched
/// — they lack the `:` body marker. Only definition lines
/// produce output.
///
/// Multi-line footnote bodies (where continuation lines are
/// indented under the definition) are out of scope: the
/// extractor sees one line at a time, so only the first
/// line of a multi-line body is captured.
///
/// 36th member of the extraction family.
SortLinesResult extractMarkdownFootnoteBodiesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'^\s*\[\^[^\]\n]+\]:\s+(.+)$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract every bare-domain URL (no protocol prefix) from each
/// selected line. Distinct from M1054 `extractUrlsFromLinesIn`
/// which requires `https?://` or `ftp://`. This one catches the
/// `example.com/path` style users write in casual prose.
///
/// Recognition: `\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s)]*)?`
/// (case-insensitive)
/// - At least one subdomain segment of lowercase-alphanumeric
///   chars (and hyphens), each followed by `.`.
/// - TLD: at least 2 alphabetic chars (so `1.5` and `192.168.1.1`
///   don't match — the TLD must be letters, not digits).
/// - Optional `/path…` consumes non-whitespace, non-`)` chars
///   (closing paren ends the URL — common at the end of a
///   parenthetical citation).
///
/// May overlap with M1054 for `https://example.com` paste-ins —
/// the protocol-prefixed form matches M1054 AND the trailing
/// `example.com` matches this extractor. De-dupe downstream
/// with sort+uniq if needed.
///
/// 37th member of the extraction family.
SortLinesResult extractBareUrlsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s)]*)?',
        caseSensitive: false,
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every 4-digit year substring (1800-2099 range) from
/// each selected line. Useful for citation / biography date
/// harvests, doc-vintage audits, and timeline scrapes.
///
/// Recognition: `\b(?:1[89]\d{2}|20\d{2})\b`
/// - 1800-1899 (`1[89]` covers 18xx and 19xx via the `[89]`
///   alternation)
/// - 2000-2099 (`20\d{2}`)
/// Outside the range — 2100+, pre-1800, 2-digit years — are
/// NOT matched. Word boundaries on each end reject embedded
/// runs in longer numeric strings.
///
/// Distinct from M1062 ISO-date extractor (full `YYYY-MM-DD`
/// shape with separators). This one is the bare year only,
/// which is the dominant prose form for citations like
/// "first published in 1923".
///
/// 38th member of the extraction family — round-number
/// milestone partner to M1100.
SortLinesResult extractYearsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b(?:1[89]\d{2}|20\d{2})\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every markdown autolink URL (`<https://x.test>` →
/// `https://x.test`) from each selected line. CommonMark allows
/// URLs wrapped in `<…>` to be rendered as links without a
/// surrounding `[text](url)` shape.
///
/// Recognition: `<((?:https?|ftp|mailto):[^>\s]+)>`
/// - Literal `<` opener.
/// - Protocol prefix: `http`, `https`, `ftp`, or `mailto`.
/// - URL content: any non-`>`, non-whitespace chars (captured).
/// - Literal `>` closer.
///
/// Distinct from:
/// - M1054 `extractUrlsFromLinesIn` (bare `https://x.test` form)
/// - M1099 `extractBareUrlsFromLinesIn` (`example.com` no protocol)
/// - M1066 `extractMarkdownLinkUrlsFromLinesIn` (inline `[t](url)`)
/// - M1094 `extractMarkdownReferenceLinkUrlsFromLinesIn` (`[label]: url`)
///
/// Five different URL surfaces, each useful for a different
/// audit pass.
///
/// 39th member of the extraction family.
SortLinesResult extractMarkdownAutolinksFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'<((?:https?|ftp|mailto):[^>\s]+)>');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every HTML tag NAME from each selected line. Useful
/// for "what HTML does this content use?" audits — pasted
/// fragments, mixed markdown+HTML docs, sanitization passes.
///
/// Recognition: `</?([a-zA-Z][\w-]*)\b[^>]*>`
/// - Optional `/` for closing tags (so `</body>` and `<body>`
///   both yield `body`).
/// - First char must be `[a-zA-Z]` — distinguishes from
///   markdown autolinks (`<https://…>` starts with `h`, then
///   `://` would fail the tag-content regex).
/// - Remaining chars `[\w-]*` cover digits and hyphens, which
///   are valid in HTML5 custom elements (`my-component`).
/// - Word boundary `\b` then any non-`>` chars (attributes).
/// - Literal `>` closer.
///
/// Self-closing tags (`<br/>`, `<img src=""/>`) match the same
/// pattern — the `/>` falls inside `[^>]*>`.
///
/// 40th member of the extraction family — round-number partner
/// to M1100. The 40-member family covers: numbers, emails,
/// URLs (5 surfaces), hashtags, mentions, wikilinks, todos
/// (open + done), ISO dates, ULIDs, hex colors, IPv4, UUIDs,
/// link labels + image alts, semver, MAC, code spans, headings,
/// blockquote / list / strikethrough / footnote ID+body,
/// fence langs, bold + italic, time-of-day, percentages,
/// currency, file sizes, git SHAs, phones, table cells,
/// ref-link defs (URL + label), years, autolinks, HTML tags.
SortLinesResult extractHtmlTagsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'</?([a-zA-Z][\w-]*)\b[^>]*>');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every HTML attribute NAME (the part before `=`) from
/// each selected line. Companion to M1102's tag-name extractor —
/// paired together they give a full inventory of what HTML
/// surface a pasted fragment uses.
///
/// Recognition: `\b([\w-]+)\s*=\s*["']`
/// - Attribute name: alphanumeric + hyphen (covers data-attrs
///   like `data-foo`).
/// - `=` with optional surrounding whitespace.
/// - Followed by a single or double quote (the start of the
///   attribute value).
///
/// Single AND double quote forms both match. Unquoted attribute
/// values (`<img src=foo>`) are NOT matched in this v1 — most
/// modern HTML uses quoted attributes; if needed, add a no-quote
/// branch in a future milestone.
///
/// 41st member of the extraction family.
SortLinesResult extractHtmlAttributeNamesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b([\w-]+)\s*=\s*["' "']");
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every HTML attribute VALUE (the part inside the
/// quotes) from each selected line. Companion to M1103's
/// attribute-name extractor — paired together they let you
/// audit both halves of every HTML attribute.
///
/// Recognition: `\b[\w-]+\s*=\s*(?:"([^"]*)"|'([^']*)')`
/// - Standard attribute-name + `=` shape.
/// - Value captured as group 1 (double-quoted) OR group 2
///   (single-quoted), one of them non-null per match.
///
/// Empty values (`href=""`) ARE matched and emit as empty
/// strings — useful for "which attributes are empty?" audits.
/// Unquoted attribute values are still out of scope (matches
/// M1103's v1 limitation).
///
/// 42nd member of the extraction family.
SortLinesResult extractHtmlAttributeValuesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'''\b[\w-]+\s*=\s*(?:"([^"]*)"|'([^']*)')''',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add((m.group(1) ?? m.group(2))!);
        }
      }
      return out;
    });

/// Extract the LABEL from every CommonMark inline reference-link
/// USAGE site (`[text][label]` → `label`) on each selected line.
/// Useful for orphan-ref audits: which labels are referenced
/// inline but not defined as `[label]: url` (M1094/M1095)?
///
/// Recognition: `\[[^\]\n]+\]\[([^\]\n]+)\]`
/// - Literal `[`, text content (any non-`]`, non-newline chars),
///   literal `]`.
/// - Immediately followed by `[`, label content (captured),
///   literal `]`.
///
/// Distinct from M1066 inline-link extractor (`[text](url)`,
/// parens form) and M1094/M1095 ref-link definitions
/// (`[label]: url` line-shape).
///
/// Collapsed form `[label][]` and shortcut form `[label]` (no
/// second bracket) are NOT matched in this v1 — the text and
/// label sections both require non-empty content per the
/// `[^\]\n]+` quantifier.
///
/// 43rd member of the extraction family. Together with M1066,
/// M1094, M1095, M1099, and M1101 this completes the markdown
/// reference / link extractor matrix for cross-checking
/// definitions vs usages.
SortLinesResult extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\[[^\]\n]+\]\[([^\]\n]+)\]');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every American-style calendar date (`January 1, 2024`,
/// `Jan 1, 2024`, `Apr 1st, 2024`) from each selected line.
/// Useful for citation parsing, meeting-minute scraping, and
/// biography date harvests where prose-style dates dominate
/// over ISO `YYYY-MM-DD` (which M1062 already handles).
///
/// Recognition: `\b(?:Jan|Feb|...|Dec)(?:[a-z]+)?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b`
/// - Abbreviated or full English month name (case-insensitive
///   via `caseSensitive: false`).
/// - Whitespace separator.
/// - Day number (1-2 digits) with optional ordinal suffix
///   (`1st`, `2nd`, `3rd`, `4th`, ...).
/// - Optional comma.
/// - Whitespace separator.
/// - 4-digit year.
///
/// No semantic validation — `Jan 32, 2024` matches even though
/// January has only 31 days. Accept for v1; downstream date-
/// parsing is the validation layer.
///
/// Day-first European form (`1 January 2024`, `01/01/2024`)
/// is out of scope for v1.
///
/// Distinct from M1062 ISO-date (`YYYY-MM-DD` numeric) and
/// M1100 4-digit year-only extractors.
///
/// 44th member of the extraction family.
SortLinesResult extractCalendarDatesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
        r'(?:[a-z]+)?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b',
        caseSensitive: false,
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every ISO 8601 week-number substring (`YYYY-Www`,
/// e.g. `2024-W12`) from each selected line. Useful for project
/// planning, sprint scheduling, and CI-build calendars.
///
/// Recognition: `\b\d{4}-W\d{2}\b`
/// - 4-digit year.
/// - Literal `-W` (uppercase `W` per ISO 8601 spec).
/// - 2-digit week number.
/// - Word boundaries on each end reject single-digit weeks
///   (`2024-W1`) and 3+ digit weeks (`2024-W123`).
///
/// No semantic validation — `2024-W54` matches even though
/// ISO years have at most 53 weeks. Acceptable for v1; the
/// downstream calendar layer can validate.
///
/// Lowercase `w` (`2024-w12`) is NOT matched — ISO 8601
/// requires uppercase `W`. If users want case-insensitive
/// matching, they can run `caseSensitive: false` toggle
/// downstream.
///
/// Distinct from M1062 ISO-date (`YYYY-MM-DD` month-day form),
/// M1100 year-only, and M1106 calendar-date prose form.
///
/// 45th member of the extraction family.
SortLinesResult extractIsoWeeksFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b\d{4}-W\d{2}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract the LABEL from every CommonMark inline image-reference
/// USAGE site (`![alt][label]` → `label`) on each selected line.
/// Companion to M1105's text-link usage label extractor — paired
/// together they give a full inventory of reference-link usages
/// (both link and image surfaces).
///
/// Recognition: `!\[[^\]\n]*\]\[([^\]\n]+)\]`
/// - Literal `!` (the marker that distinguishes image refs
///   from text-link refs).
/// - `[alt]` opener (alt allowed to be EMPTY per CommonMark, so
///   `[^\]\n]*` zero-or-more).
/// - `]` closer.
/// - Immediately followed by `[label]` (label requires non-empty
///   content per `[^\]\n]+`).
///
/// Inline image form `![alt](url)` (M1073) and collapsed form
/// `![alt][]` are NOT matched in this v1.
///
/// 46th member of the extraction family.
SortLinesResult extractMarkdownImageReferenceUsageLabelsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'!\[[^\]\n]*\]\[([^\]\n]+)\]');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every CIDR-notation IPv4 substring (`a.b.c.d/N`) from
/// each selected line. Useful for firewall-rule audits, network
/// scope reviews, and routing-table scrapes.
///
/// Recognition: `\b(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}\b`
/// - Three groups of 1-3 digits + `.`.
/// - Final 1-3 digit octet.
/// - Literal `/`.
/// - 1-2 digit prefix length.
/// - Word boundaries on each end.
///
/// No semantic validation — `999.999.999.999/99` matches even
/// though octets cap at 255 and prefix at 32. Acceptable for v1;
/// downstream network-layer code validates ranges. Strict IPv4
/// validation is M1064's job.
///
/// 47th member of the extraction family.
SortLinesResult extractCidrFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract the content of every HTML comment (`<!-- text -->` →
/// `text`) on each selected line. Useful for hidden-comment
/// audits, harvesting `<!-- TODO: -->` notes, and reviewing
/// content that lives inside HTML comments but doesn't render.
///
/// Recognition: `<!--\s*([^\n]*?)\s*-->`
/// - Literal `<!--` opener.
/// - Optional leading / trailing whitespace inside the comment
///   (trimmed from the capture).
/// - Content captured non-greedily so the FIRST closing `-->`
///   ends the match — multi-comment-per-line still works.
/// - `[^\n]` excludes newlines, so multi-line comments only
///   yield the first line's content.
///
/// 48th member of the extraction family.
SortLinesResult extractHtmlCommentsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'<!--\s*([^\n]*?)\s*-->');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the DOMAIN portion from every email address on each
/// selected line (`user@example.com` → `example.com`). Companion
/// to M1053's full-email extractor — useful for "which email
/// providers does this contact list use?" audits, deliverability
/// review, and bulk-import provider distribution.
///
/// Recognition mirrors M1053's email regex but the local-part
/// section is now non-capturing while the domain section is
/// captured as group 1.
///
/// 49th member of the extraction family.
SortLinesResult extractEmailDomainsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'[A-Za-z0-9._%+\-]+@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the LOCAL-PART (the part before `@`) from every email
/// address on each selected line (`user@example.com` → `user`).
/// Completes the email triplet:
/// - M1053 `extractEmailsFromLinesIn` — full `user@example.com`
/// - M1112 `extractEmailDomainsFromLinesIn` — `example.com`
/// - M1113 `extractEmailLocalPartsFromLinesIn` — `user`
///
/// Useful for username-convention audits, "what are the
/// dominant local-part shapes in this contact list?" and
/// PII-anonymization passes that keep the structure but
/// scrub the domain.
///
/// Recognition mirrors M1053/M1112 with the local-part as the
/// captured group:
/// `([A-Za-z0-9._%+\-]+)@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`
///
/// 50th member of the extraction family — round-number
/// milestone for the family.
SortLinesResult extractEmailLocalPartsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'([A-Za-z0-9._%+\-]+)@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the ALIAS portion from every wikilink with a custom
/// display name (`[[ULID|alias]]` → `alias`) on each selected
/// line. Companion to the full wikilink extractor — useful for
/// "what custom display names does this doc use?" audits and
/// internationalization / localization sweeps.
///
/// Recognition:
/// `\[\[[0-9A-Z]{26}(?:#[a-z0-9][a-z0-9\-]*)?\|([^\]\n]+)\]\]`
/// - Standard wikilink opener `[[` + 26-char ULID.
/// - Optional `#anchor-slug` (lowercase + digits + hyphen).
/// - Literal `|` then the alias content (captured as group 1).
/// - Literal `]]` closer.
///
/// Wikilinks WITHOUT an alias (`[[ULID]]` plain) are NOT
/// matched — the `|` is the required marker.
///
/// 51st member of the extraction family.
SortLinesResult extractWikilinkAliasesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\[\[[0-9A-Z]{26}(?:#[a-z0-9][a-z0-9\-]*)?\|([^\]\n]+)\]\]',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract the ANCHOR slug from every wikilink that has one
/// (`[[ULID#anchor]]` or `[[ULID#anchor|alias]]` → `anchor`)
/// on each selected line. Companion to M1114's alias extractor
/// — useful for "which sections does this doc deep-link to?"
/// audits and anchor-slug consistency reviews.
///
/// Recognition:
/// `\[\[[0-9A-Z]{26}#([a-z0-9][a-z0-9\-]*)(?:\|[^\]\n]*)?\]\]`
/// - Standard wikilink opener `[[` + 26-char ULID.
/// - Literal `#` then the anchor slug (captured as group 1):
///   starts with `[a-z0-9]`, followed by lowercase + digits +
///   hyphens.
/// - Optional `|alias` (consumed but not captured).
/// - Literal `]]` closer.
///
/// Wikilinks WITHOUT an anchor (`[[ULID]]` or `[[ULID|alias]]`)
/// are NOT matched — the `#anchor` is the required marker.
///
/// 52nd member of the extraction family. The wikilink trio
/// (full body, alias, anchor) is now complete — three
/// complementary surfaces for vault analysis.
SortLinesResult extractWikilinkAnchorsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\[\[[0-9A-Z]{26}#([a-z0-9][a-z0-9\-]*)(?:\|[^\]\n]*)?\]\]',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every YouTube video ID from each selected line. Useful
/// for video-list audits, embed-roster scrapes, and bulk
/// playlist building from prose notes.
///
/// Supported URL surfaces:
/// - `youtu.be/VIDEO_ID` (short form)
/// - `youtube.com/watch?v=VIDEO_ID` (full form)
/// - `youtube.com/embed/VIDEO_ID` (iframe embed form)
///
/// All forms with or without `https://` / `http://` / `www.`
/// prefix. The video ID is exactly 11 chars from
/// `[A-Za-z0-9_-]` per YouTube's spec.
///
/// 53rd member of the extraction family.
SortLinesResult extractYoutubeIdsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)'
        r'([A-Za-z0-9_-]{11})',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every `owner/repo` path from GitHub URLs on each
/// selected line. Useful for repo-list audits, dependency
/// inventory, and PR-link harvesting.
///
/// Recognition: `github\.com/([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}[A-Za-z0-9])?/[A-Za-z0-9._-]+)`
/// - `github.com/` literal anchor (the URL surface that
///   distinguishes GitHub from generic `owner/repo` strings).
/// - Username: starts with alphanumeric, can contain hyphens,
///   max 39 chars total, can't end with hyphen (per GitHub's
///   username rules).
/// - Single literal `/`.
/// - Repo name: alphanumeric plus `_`, `-`, `.` per GitHub's
///   repo-name rules.
///
/// 54th member of the extraction family.
SortLinesResult extractGithubRepoPathsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'github\.com/'
        r'([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}[A-Za-z0-9])?'
        r'/[A-Za-z0-9._-]+)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every compound year-range substring (`YYYY-YYYY` or
/// `YYYY–YYYY` with em-dash) from each selected line. Useful
/// for citation timespan audits, copyright-year scrapes,
/// career-range harvests, and historical-range analysis.
///
/// Recognition: `\b\d{4}[-–]\d{4}\b`
/// - First 4-digit year.
/// - Hyphen OR em-dash (`–`, `U+2013`) separator.
/// - Second 4-digit year.
/// - Word boundaries on each end.
///
/// No semantic validation — `9999-9999` matches even though
/// years that far in the future are usually not citations.
/// Accept for v1.
///
/// Abbreviated range forms (`2024-25`, `1980s-90s`) are NOT
/// matched — both sides require exactly 4 digits, which is
/// the dominant academic / archival convention.
///
/// Distinct from M1100 4-digit year-only and M1062 ISO date
/// extractors. Complements them as the timespan surface.
///
/// 55th member of the extraction family.
SortLinesResult extractYearRangesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // The em-dash `–` (U+2013) and the basic hyphen `-` both
      // count as separators. Other dash variants (em-dash `—`
      // U+2014, hyphen-minus is already the basic `-`) are
      // out of scope.
      final re = RegExp(r'\b\d{4}[-–]\d{4}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every DOI (Digital Object Identifier) substring from
/// each selected line. Useful for academic citation harvest,
/// paper-reference audit, and bibliography mining.
///
/// DOI format per the spec: `10.PREFIX/SUFFIX`
/// - `10.` literal namespace marker.
/// - PREFIX: 4-9 digit registrant code.
/// - `/` literal.
/// - SUFFIX: registrant-defined opaque identifier (alphanumeric
///   plus `-._;():/`).
///
/// Recognition: `\b10\.\d{4,9}/[\-._;()/:A-Za-z0-9]+`
///
/// Catches both bare DOIs (`10.1000/xyz123`) and DOIs embedded
/// in resolver URLs (`https://doi.org/10.1000/xyz123` —
/// captured portion is `10.1000/xyz123`, the resolver prefix
/// is leftover).
///
/// 56th member of the extraction family.
SortLinesResult extractDoiFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b10\.\d{4,9}/[\-._;()/:A-Za-z0-9]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every file extension substring from each selected
/// line. Useful for filename audits, asset-type counting, and
/// "what file types does this doc reference?" surveys.
///
/// Recognition: `\.(?=[a-zA-Z0-9]*[a-zA-Z])([a-zA-Z0-9]{1,6})\b`
/// - Literal `.` opener.
/// - Lookahead requires AT LEAST ONE letter somewhere in the
///   extension — this is what distinguishes `1.5` (decimal,
///   skipped) from `archive.7z` (file ext with mixed digits +
///   letter, captured).
/// - 1-6 alphanumeric chars captured (the extension text
///   without the leading dot).
/// - Word boundary on close.
///
/// Multi-extension files (`archive.tar.gz`) yield BOTH
/// extensions as separate captures (`tar` and `gz`) — the
/// regex matches each `.ext` independently. Filter to "last
/// per filename" downstream if you need just the final.
///
/// Case is preserved: `report.PDF` → `PDF` (not lowercased).
///
/// 57th member of the extraction family.
SortLinesResult extractFileExtensionsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\.(?=[a-zA-Z0-9]*[a-zA-Z])([a-zA-Z0-9]{1,6})\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every ISBN-13 substring from each selected line.
/// Useful for book-inventory mining, bibliography parsing, and
/// catalog audits.
///
/// Recognition: `\b97[89][-\s]?(?:\d[-\s]?){9}\d\b`
/// - GS1 prefix `978` or `979` (strict ISBN-13 namespace).
/// - 10 more digits (registration group + publisher + title +
///   check), each optionally preceded by a hyphen or single
///   whitespace separator.
/// - Word boundaries on each end reject embedded slices.
///
/// Captures common formats:
/// - Bare: `9783161484100`
/// - Hyphenated: `978-3-16-148410-0` (standard book-cover form)
/// - Space-separated: `978 3 16 148410 0`
///
/// No semantic check-digit validation — `978-3-16-148410-9`
/// matches even if the trailing 9 isn't the correct
/// computed check digit. Downstream layer validates if needed.
///
/// ISBN-10 (no `978`/`979` prefix, 10 digits with possible `X`
/// check) is out of scope for v1 — most modern books use
/// ISBN-13 since 2007.
///
/// 58th member of the extraction family.
SortLinesResult extractIsbn13FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b97[89][-\s]?(?:\d[-\s]?){9}\d\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every JIRA-style ticket reference (`PROJ-1234`) from
/// each selected line. Useful for sprint reviews, retro notes,
/// release-notes audits, and "which tickets does this doc
/// reference?" surveys.
///
/// Recognition: `\b[A-Z]{2,10}-\d+\b`
/// - 2-10 uppercase letters (project key).
/// - Literal `-`.
/// - One or more digits (ticket number).
/// - Word boundaries on each end.
///
/// Lowercase project keys (`proj-123`) are NOT matched — JIRA
/// convention uses uppercase. Single-letter keys (`A-123`) are
/// NOT matched — most JIRA installs require 2+ chars.
///
/// The project-key length cap at 10 is a heuristic to avoid
/// catching arbitrary `LONGWORD-123` strings. Real JIRA keys
/// are usually 2-4 chars (`PROJ`, `OPS`) but occasionally
/// longer for enterprise installs.
///
/// 59th member of the extraction family.
SortLinesResult extractJiraTicketsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[A-Z]{2,10}-\d+\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every GitHub-style PR/issue reference (`#1234`)
/// from each selected line. Distinct from hashtags (`#word`)
/// — this one specifically pulls numeric references commonly
/// used in changelogs, release notes, and commit messages.
///
/// Recognition: `(?<!\w)#\d+\b`
/// - Lookbehind blocks matches embedded in words (`abc#123`
///   skipped).
/// - Literal `#`.
/// - One or more digits.
/// - Word boundary on close.
///
/// Hashtags (`#tag`, `#bug-fix`) are NOT matched — those are
/// M1055's surface (`extractHashtagsFromLinesIn`). The numeric
/// constraint disambiguates.
///
/// 60th member of the extraction family — round-number
/// milestone for the family count.
SortLinesResult extractPrIssueRefsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<!\w)#\d+\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Roman numeral substring (strict 1-3999 form,
/// uppercase only) from each selected line. Useful for
/// outline / chapter notation audits, book index harvests, and
/// historical-date scraping.
///
/// Recognition: `\b(?=[MDCLXVI])M{0,4}(?:CM|CD|D?C{0,3})(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})\b`
/// - Lookahead `(?=[MDCLXVI])` blocks zero-content matches
///   on word boundaries (would match empty at every `\b`
///   otherwise).
/// - Standard Roman-numeral grammar enforcing valid letter
///   sequences (M up to 4 times, then 9/4/0-3 hundreds,
///   tens, units).
/// - Word boundaries on each end.
///
/// Lowercase form (`iv`, `mcmxcix`) is NOT matched — Roman
/// numerals in outline / chapter notation almost always use
/// uppercase, and supporting lowercase would conflict with
/// common English words ending in `i` / `v` / `x`.
///
/// 61st member of the extraction family.
SortLinesResult extractRomanNumeralsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?=[MDCLXVI])M{0,4}(?:CM|CD|D?C{0,3})'
        r'(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every latitude/longitude coordinate pair from each
/// selected line. Useful for travel-log mining, map-reference
/// harvest, and GIS data scraping from prose notes.
///
/// Recognition: `-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+`
/// - Optional leading minus sign (southern / western
///   hemispheres).
/// - 1-3 digit integer part.
/// - Literal `.`.
/// - One or more decimal digits.
/// - Comma separator with optional surrounding whitespace.
/// - Same shape repeated for longitude.
///
/// No semantic range validation — `1.5,2.5` matches even
/// though those are unlikely real coordinates. Acceptable
/// for v1 since the comma+two-decimals shape is rare in
/// prose outside the coordinate use case.
///
/// 62nd member of the extraction family.
SortLinesResult extractLatLngFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Ethereum-style hex address substring
/// (`0x` + 40 hex chars) from each selected line. Useful for
/// smart-contract documentation, wallet-list audits, and
/// blockchain reference scraping.
///
/// Recognition: `\b0x[a-fA-F0-9]{40}\b`
/// - Literal `0x` prefix (the Ethereum address marker).
/// - Exactly 40 hex digits (the address itself — 20 bytes /
///   160 bits per the EVM spec).
/// - Word boundaries on each end.
///
/// Case is preserved — both lowercase (`0xabc...`) and EIP-55
/// mixed-case checksum forms (`0xAbC...`) extract intact.
///
/// 63rd member of the extraction family.
SortLinesResult extractEthAddressesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b0x[a-fA-F0-9]{40}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every MongoDB ObjectId substring (24 hex chars,
/// with at least one letter) from each selected line. Useful
/// for NoSQL doc audits, debug log triage, and ID-extraction
/// from MongoDB connection paste-ins.
///
/// Recognition: `\b(?=[0-9a-fA-F]*[a-fA-F])[0-9a-fA-F]{24}\b`
/// - Exactly 24 hex digits (the canonical ObjectId length).
/// - Lookahead requires AT LEAST ONE letter to distinguish
///   from 24-digit numbers that happen to share the same
///   length.
/// - Word boundaries on each end.
/// - Case-insensitive matching across upper/lower hex.
///
/// Overlaps with M1091 git short SHA extractor (7-40 hex
/// chars). A 24-char hex with letters matches BOTH; use
/// whichever surface fits the docs domain.
///
/// 64th member of the extraction family.
SortLinesResult extractMongoObjectIdsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?=[0-9a-fA-F]*[a-fA-F])[0-9a-fA-F]{24}\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every AWS ARN substring (`arn:PARTITION:SERVICE:REGION:ACCOUNT:RESOURCE`)
/// from each selected line. Useful for infrastructure docs,
/// IAM policy audits, and cross-account resource inventory.
///
/// Recognition: `\barn:[\w\-]+:[\w\-]+:[\w\-]*:\d{0,12}:[\w/\-:.,*]+`
/// - `arn:` literal namespace marker.
/// - Partition (`aws`, `aws-cn`, `aws-us-gov`, etc.): alphanumeric
///   + hyphen.
/// - Service (`s3`, `iam`, `lambda`, etc.): alphanumeric + hyphen.
/// - Region (`us-east-1`, optional empty for global services):
///   alphanumeric + hyphen, can be empty.
/// - Account-id: 0-12 digits (empty allowed for global / public
///   resources).
/// - Resource: alphanumeric plus `/`, `-`, `:`, `.`, `,`, `*`.
///
/// 65th member of the extraction family.
SortLinesResult extractAwsArnsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\barn:[\w\-]+:[\w\-]+:[\w\-]*:\d{0,12}:[\w/\-:.,*]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract the OUI (the first 3 octets, vendor / manufacturer
/// prefix) from every MAC address on each selected line.
/// Companion to M1076's full-MAC extractor — useful for
/// "which network vendors does this scan show?" audits where
/// the host-specific bytes don't matter.
///
/// Recognition:
///   `\b([0-9a-fA-F]{2}([:-])[0-9a-fA-F]{2}\2[0-9a-fA-F]{2})`
///   `\2[0-9a-fA-F]{2}\2[0-9a-fA-F]{2}\2[0-9a-fA-F]{2}\b`
/// - Full 6-octet MAC shape with same-separator enforcement via
///   backref `\2`.
/// - Capture group 1 = first 3 octets (the OUI portion).
///
/// Either colon or hyphen separator is supported. Mixed-form
/// runs are rejected (same as M1076 full-MAC).
///
/// 66th member of the extraction family.
SortLinesResult extractMacOuisFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b([0-9a-fA-F]{2}([:-])[0-9a-fA-F]{2}\2[0-9a-fA-F]{2})'
        r'\2[0-9a-fA-F]{2}\2[0-9a-fA-F]{2}\2[0-9a-fA-F]{2}\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every Twitter/X status ID from each selected line.
/// Useful for tweet-list audits, citation harvest, and bulk
/// embed-roster building from prose notes.
///
/// Supports both URL surfaces:
/// - `twitter.com/USER/status/ID` (legacy)
/// - `x.com/USER/status/ID` (post-rebrand)
///
/// Recognition:
///   `(?:twitter\.com|x\.com)/[\w.]+/status/(\d+)`
/// - Either `twitter.com` or `x.com` domain anchor.
/// - Username segment (alphanumeric + `_` + `.`).
/// - Literal `/status/` path marker.
/// - Numeric tweet ID captured as group 1.
///
/// Optional `https://` / `http://` / `www.` URL prefix is
/// captured implicitly — the regex doesn't require it, so
/// both protocol-prefixed and bare forms match.
///
/// 67th member of the extraction family.
SortLinesResult extractTwitterStatusIdsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?:twitter\.com|x\.com)/[\w.]+/status/(\d+)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every GitHub issue or PR number from a GitHub URL
/// on each selected line. Useful for cross-repo PR/issue
/// audits, release-note compilation, and bug-tracker mining.
///
/// Recognition:
///   `github\.com/[\w.-]+/[\w.-]+/(?:issues|pull)/(\d+)`
/// - `github.com/` anchor.
/// - `owner/repo` path segment.
/// - Literal `/issues/` or `/pull/` marker.
/// - Numeric ID captured as group 1.
///
/// Distinct from M1123 `extractPrIssueRefsFromLinesIn` which
/// captures `#1234` inline-reference syntax. This extractor
/// targets full-URL references (cross-repo PR mentions).
///
/// 68th member of the extraction family.
SortLinesResult extractGithubIssuePrNumbersFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'github\.com/[\w.-]+/[\w.-]+/(?:issues|pull)/(\d+)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every NPM scoped package name (`@scope/name`) from
/// each selected line. Useful for dependency audit, package
/// inventory, and migration tracking.
///
/// Recognition: `@[a-z0-9][\w.-]*/[a-z0-9][\w.-]*`
/// - Literal `@` namespace marker.
/// - Scope: lowercase alphanumeric start, then alphanumeric +
///   `_` + `-` + `.`.
/// - Literal `/`.
/// - Package name: same shape as scope.
///
/// Lowercase enforced per NPM convention. Mixed-case forms
/// (`@FLUTTER/Material`) are NOT matched. Unscoped packages
/// (`react`, `lodash`) are NOT matched — they're too easily
/// confused with English words; if a doc explicitly cites
/// `react` as a dep, the `@scope/` form usually appears
/// elsewhere for context.
///
/// 69th member of the extraction family.
SortLinesResult extractNpmScopedPackagesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'@[a-z0-9][\w.-]*/[a-z0-9][\w.-]*');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every HTTP status code substring (1XX-5XX range)
/// from each selected line. Useful for log triage, API doc
/// audits, and "which errors does this incident report
/// mention?" surveys.
///
/// Recognition: `\b[1-5]\d{2}\b`
/// - First digit 1-5 (covers 1XX informational through 5XX
///   server-error families).
/// - Two more digits.
/// - Word boundaries on each end.
///
/// No semantic validation — `199` matches even though there's
/// no canonical HTTP 199 code. Acceptable for v1 since the
/// 3-digit shape in the 100-599 range is rare outside HTTP
/// status contexts. 4-digit numbers (`2024`) and 2-digit
/// numbers (`99`) are correctly skipped.
///
/// 70th member of the extraction family — round-number
/// milestone.
SortLinesResult extractHttpStatusCodesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[1-5]\d{2}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Stack Overflow question ID from a Stack
/// Overflow URL on each selected line. Useful for citation
/// audit, "which SO answers does this design doc link?"
/// surveys, and reference-list scrubbing.
///
/// Recognition: `stackoverflow\.com/(?:questions|q)/(\d+)`
/// - `stackoverflow.com/` anchor.
/// - Path segment: `questions` (canonical) OR `q` (short URL).
/// - Numeric question ID captured as group 1.
///
/// The trailing `/title-slug` portion (if any) is correctly
/// excluded — the regex stops at the digits.
///
/// 71st member of the extraction family.
SortLinesResult extractStackOverflowQuestionIdsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'stackoverflow\.com/(?:questions|q)/(\d+)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every database connection-string URL from each
/// selected line. Useful for infra docs, secret-rotation audits,
/// and config-leak scrubbing.
///
/// Supported schemes:
/// - `mongodb://...` / `mongodb+srv://...` (MongoDB)
/// - `postgresql://...` / `postgres://...` (PostgreSQL)
/// - `mysql://...` (MySQL)
/// - `redis://...` / `rediss://...` (Redis, TLS variant)
///
/// Recognition:
///   `(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|rediss?)://[^\s]+`
///
/// Distinct from M1054 generic URL extractor (which catches
/// `https://` / `http://` / `ftp://`). This one targets the
/// database-specific schemes that don't show up in regular
/// web-URL paste-ins.
///
/// 72nd member of the extraction family.
SortLinesResult extractDbConnectionStringsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|rediss?)://[^\s]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every CSS `rgb(...)` / `rgba(...)` color expression
/// from each selected line. Useful for design doc audits, CSS
/// style sweeps, and color-palette extraction from notes.
///
/// Recognition:
///   `rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+(?:\s*,\s*[\d.]+)?\s*\)`
/// - `rgb` or `rgba` literal.
/// - Opening `(`.
/// - Three comma-separated integers (the channels).
/// - Optional fourth comma-separated number (alpha).
/// - Closing `)`.
/// Whitespace around commas tolerated; values not range-
/// validated (so `rgb(999,999,999)` matches even though it's
/// out of spec).
///
/// Distinct from M1063 hex-color extractor (`#abc` / `#aabbcc`).
/// Together they cover the dominant CSS color formats.
///
/// 73rd member of the extraction family.
SortLinesResult extractRgbColorsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+(?:\s*,\s*[\d.]+)?\s*\)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every CSS `hsl(...)` / `hsla(...)` color expression
/// from each selected line. Completes the CSS-color trio
/// alongside M1063 hex and M1137 RGB extractors.
///
/// Recognition:
///   `hsla?\(\s*\d+\s*,\s*\d+%\s*,\s*\d+%(?:\s*,\s*[\d.]+)?\s*\)`
/// - `hsl` or `hsla` literal.
/// - Opening `(`.
/// - Hue: integer (0-360 conventionally, but unvalidated).
/// - Comma + saturation: integer + `%`.
/// - Comma + lightness: integer + `%`.
/// - Optional comma + alpha: number (decimal or integer).
/// - Closing `)`.
///
/// Modern CSS `hsl(120deg 50% 50%)` space-separated form is
/// out of scope for v1 — the legacy comma-separated form is
/// still dominant in design docs.
///
/// 74th member of the extraction family.
SortLinesResult extractHslColorsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'hsla?\(\s*\d+\s*,\s*\d+%\s*,\s*\d+%(?:\s*,\s*[\d.]+)?\s*\)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Linux absolute-path substring from each
/// selected line (`/etc/passwd`, `/usr/local/bin/foo`, etc.).
/// Useful for sysadmin docs, config-audit notes, deployment
/// playbooks.
///
/// Recognition: `(?<![\w/])/[\w.-]+(?:/[\w.-]+)+`
/// - Lookbehind blocks matches preceded by a word or `/`
///   char — `1/2/3` (math) is correctly skipped.
/// - Leading `/`.
/// - First segment: alphanumeric + `_` + `-` + `.`.
/// - At least ONE additional `/segment` (so single-segment
///   `/usr` doesn't match — requires `/usr/local` minimum).
///
/// Distinct from URL paths (M1054 / M1099) — those start with
/// a protocol scheme. Distinct from Windows paths (backslash
/// separator).
///
/// 75th member of the extraction family.
SortLinesResult extractLinuxPathsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<![\w/])/[\w.-]+(?:/[\w.-]+)+');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Windows absolute-path substring from each
/// selected line (`C:\Users\foo`, `D:\Projects\repo\file.txt`).
/// Companion to M1139's Linux-path extractor — together they
/// cover both major filesystem-path conventions.
///
/// Recognition: `[A-Za-z]:\\[\w.-]+(?:\\[\w.-]+)*`
/// - Drive letter (single uppercase / lowercase ASCII letter).
/// - Literal `:` then `\`.
/// - At least one segment (alphanumeric + `_` + `-` + `.`).
/// - Zero or more additional `\segment` parts.
///
/// Single-segment paths like `C:\Users` ARE matched (unlike
/// Linux paths which require 2+ segments). Windows convention
/// is to write the bare drive letter as `C:\` (just the drive),
/// not just `C:`, so `C:\Users` is the minimal sensible shape.
///
/// UNC paths (`\\server\share`) are out of scope for v1.
///
/// 76th member of the extraction family — M1140 round-number
/// milestone.
SortLinesResult extractWindowsPathsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'[A-Za-z]:\\[\w.-]+(?:\\[\w.-]+)*');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every PEM block type from PEM header lines on each
/// selected line. PEM blocks open with `-----BEGIN <TYPE>-----`
/// — useful for cert/key audit, PKI inventory, and "what kind
/// of cryptographic material does this paste-in contain?" surveys.
///
/// Recognition: `-----BEGIN ([A-Z][A-Z0-9 ]*[A-Z])-----`
/// - Five literal dashes + `BEGIN ` opener.
/// - Block type: uppercase letters, digits, and spaces; must
///   start and end with a letter (so `PUBLIC KEY` and
///   `RSA PRIVATE KEY` work but `PUBLIC ` with trailing space
///   doesn't).
/// - Five literal dashes closer.
///
/// Common PEM block types captured:
/// - `CERTIFICATE`, `CERTIFICATE REQUEST`
/// - `PRIVATE KEY`, `PUBLIC KEY`, `RSA PRIVATE KEY`,
///   `EC PRIVATE KEY`, `DSA PRIVATE KEY`
/// - `ENCRYPTED PRIVATE KEY`
/// - `X509 CRL`, `PKCS7`
///
/// Captures only the block-TYPE portion (not the BEGIN line
/// itself).
///
/// 77th member of the extraction family.
SortLinesResult extractPemBlockTypesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'-----BEGIN ([A-Z][A-Z0-9 ]*[A-Z])-----',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every JWT (JSON Web Token) substring from each
/// selected line. Useful for auth log triage, debugging
/// session-token issues, and "is there a leaked token in
/// this paste-in?" sweeps.
///
/// Recognition:
///   `\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`
/// - `eyJ` prefix: base64-url encoding of `{"` — the
///   canonical JWT-header opener, present in every JWT.
/// - First two segments must start with `eyJ` (the header
///   and payload, both JSON objects).
/// - Third segment: base64-url chars only (the signature).
/// - Dot separators between segments.
///
/// The `eyJ` prefix on both header and payload segments is
/// what disambiguates JWTs from arbitrary 3-part dot-separated
/// base64-url strings.
///
/// 78th member of the extraction family.
SortLinesResult extractJwtFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Bitcoin address substring from each selected
/// line. Covers the three dominant address formats:
/// - Legacy P2PKH: `1` + 25-34 base58 chars
/// - P2SH: `3` + 25-34 base58 chars
/// - Bech32 (SegWit): `bc1` + 39-59 lowercase chars
///
/// Useful for crypto-transaction docs, wallet inventory, and
/// "is there a public address leaked here?" sweeps.
///
/// Recognition:
///   `\b(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|bc1[a-z0-9]{39,59})\b`
/// - Word boundaries on each end.
/// - Legacy / P2SH: base58 character class (no `0`, `O`, `I`,
///   `l` — Bitcoin's confusable-char exclusion).
/// - Bech32: lowercase alphanumeric (the full spec is more
///   restrictive but `[a-z0-9]` covers the practical space
///   without false-positive risk in non-bech32 text).
///
/// 79th member of the extraction family.
SortLinesResult extractBitcoinAddressesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|bc1[a-z0-9]{39,59})\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Cisco-style MAC address (dot-separated
/// `XXXX.XXXX.XXXX`) from each selected line. Companion to
/// M1076's standard MAC extractor (colon / hyphen separators).
///
/// Recognition: `\b[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\b`
/// - Three groups of 4 hex digits.
/// - Two literal `.` separators.
/// - Word boundaries on each end.
///
/// This is the dotted-quad-of-quads form Cisco IOS uses (and
/// many network appliances mirror). Distinct from the
/// canonical `XX:XX:XX:XX:XX:XX` form (M1076) and the OUI
/// extractor (M1130).
///
/// Mixed-case hex digits supported. Wrong segment count
/// (2 or 4 groups) or wrong digit count per group are
/// rejected.
///
/// 80th member of the extraction family — round milestone.
SortLinesResult extractMacAddressesCiscoFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every HTML entity reference from each selected
/// line. Useful for entity-usage audit, decoding prep, and
/// "what character references does this scraped HTML use?"
/// surveys.
///
/// Recognition:
///   `&(?:[a-zA-Z][a-zA-Z0-9]+|#\d+|#x[0-9a-fA-F]+);`
/// - Literal `&` opener.
/// - One of three entity forms:
///   - Named: alphabetic start + alphanumeric tail
///     (e.g. `amp`, `lt`, `gt`, `nbsp`, `copy`).
///   - Numeric decimal: `#` + digits (e.g. `#39`).
///   - Numeric hex: `#x` + hex digits (e.g. `#x27`).
/// - Literal `;` closer.
///
/// Plain `&` (no entity body) and unterminated entities
/// (no closing `;`) are correctly skipped.
///
/// 81st member of the extraction family.
SortLinesResult extractHtmlEntitiesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'&(?:[a-zA-Z][a-zA-Z0-9]+|#\d+|#x[0-9a-fA-F]+);',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract the checkbox STATE from every markdown task-list
/// item (`[ ]`, `[x]`, `[X]`) on each selected line. Useful
/// for "done vs open" audits, completion-rate analysis, and
/// pivot from body to state in todo-style outlines.
///
/// Distinct from M1056 done-todos and open-todos extractors
/// which emit the BODY (text after the checkbox). This one
/// emits only the state character — `x` or `X` for done,
/// ` ` (space) for open — useful for tallying without reading
/// the body content.
///
/// Recognition: `\[([ xX])\]`
/// - Literal `[`.
/// - Exactly one of `space`, `x`, or `X` (captured).
/// - Literal `]`.
///
/// Plain `[foo]` (multi-char body) is NOT a match — only the
/// single-char checkbox slot counts.
///
/// 82nd member of the extraction family.
SortLinesResult extractMarkdownTaskStatesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\[([ xX])\]');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(1)!);
        }
      }
      return out;
    });

/// Extract every Slack-style mention/channel reference from
/// each selected line. Useful for Slack export audit,
/// reaction-roster harvest, and "who/what does this thread
/// reference?" surveys.
///
/// Supported Slack reference forms:
/// - User mention:    `<@U12345>` (with optional `|alias`)
/// - Channel mention: `<#C12345>` (with optional `|name`)
/// - User-group:      `<!subteam^S12345>` (out of scope v1)
///
/// Recognition: `<[@#][A-Z][A-Z0-9]+(?:\|[^>]+)?>`
/// - `<` opener.
/// - `@` (user) or `#` (channel) sigil.
/// - Slack ID: uppercase letter start + alphanumeric tail.
///   Slack IDs are `U…` for users and `C…` for channels but
///   the regex accepts any uppercase-leading ID for forward
///   compat.
/// - Optional `|alias` (consumed but kept in the match).
/// - `>` closer.
///
/// Distinct from M1056 mentions (plain `@alice` form) which
/// is the prose convention, not the export-format convention.
///
/// 83rd member of the extraction family.
SortLinesResult extractSlackMentionsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'<[@#][A-Z][A-Z0-9]+(?:\|[^>]+)?>');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Discord-style mention/channel/role reference
/// from each selected line. Companion to M1147's Slack-format
/// extractor — Discord uses purely numeric snowflake IDs.
///
/// Supported Discord reference forms:
/// - User mention:    `<@123>` (with or without `!` nickname
///                              prefix for `<@!123>`)
/// - Role mention:    `<@&123>`
/// - Channel mention: `<#123>`
///
/// Recognition: `<(?:@!?|@&|#)\d+>`
/// - `<` opener.
/// - Sigil: `@`, `@!` (nickname mention), `@&` (role), or `#`.
/// - Numeric snowflake ID (typically 17-19 digits but
///   unvalidated here).
/// - `>` closer.
///
/// Slack mentions (`<@U12345>` with letter-prefix IDs) are
/// NOT matched — they're M1147's surface. The numeric-vs-
/// letter ID prefix disambiguates the two platforms.
///
/// 84th member of the extraction family.
SortLinesResult extractDiscordMentionsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'<(?:@!?|@&|#)\d+>');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every NPM-style semver-range expression from each
/// selected line. Useful for dependency audit, version-bump
/// surveys, and `package.json` paste-in mining.
///
/// Supported range operators:
/// - Caret:      `^1.2.3` (compatible with version)
/// - Tilde:      `~1.2.3` (approximately equivalent)
/// - Comparison: `>1.2.3`, `>=1.2.3`, `<2.0.0`, `<=1.2.3`
/// - Exact:      `=1.2.3`
///
/// Recognition: `(?:[\^~]|[<>]=?|=)\d+\.\d+\.\d+`
/// - One of the range operators (no boundary needed since
///   the operators themselves are non-word chars).
/// - Three-segment semver (MAJOR.MINOR.PATCH).
///
/// Pre-release and build metadata (`-rc.1`, `+sha.abc`) are
/// out of scope for v1 — range pinning rarely needs them.
/// Bare semvers without operators are M1074's surface.
///
/// 85th member of the extraction family.
SortLinesResult extractNpmSemverRangesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?:[\^~]|[<>]=?|=)\d+\.\d+\.\d+');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every HTTP method + path token from each selected
/// line (e.g. `GET /api/users`, `POST /v1/login`). Useful for
/// REST API doc audits, route inventory, and OpenAPI spec
/// authoring.
///
/// Recognition: `\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE|CONNECT)\s+/[^\s]+`
/// - Standard HTTP method (uppercase, all nine RFC 7231 +
///   RFC 5789 PATCH).
/// - Whitespace.
/// - Path starting with `/` (no spaces inside the path).
///
/// Lowercase methods (`get /path`) are NOT matched — HTTP
/// methods are conventionally uppercase in doc tables and
/// curl examples. Bare methods without paths are skipped.
///
/// 86th member of the extraction family.
SortLinesResult extractHttpMethodsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE|CONNECT)'
        r'\s+/[^\s]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every MIME type token from each selected line.
/// Useful for HTTP doc audits, Content-Type header harvests,
/// OpenAPI spec authoring, and accept-header inventory.
///
/// Recognition: `\b(application|audio|font|example|image|message|
/// model|multipart|text|video)/[A-Za-z0-9][A-Za-z0-9.\-+]*\b`
/// - Top-level type is one of the ten IANA-registered roots.
/// - Slash separator (required).
/// - Subtype starts with an alphanumeric and may contain `.`,
///   `-`, `+` afterward. Examples that match: `application/json`,
///   `application/vnd.api+json`, `text/html`, `image/png`,
///   `application/x-www-form-urlencoded`, `model/gltf+json`.
///
/// The parameter portion (`; charset=utf-8`) is NOT captured —
/// only the bare `type/subtype` token is returned, which is
/// almost always what doc audits want. Filter parameters
/// downstream with a separate pass if needed.
///
/// Top-level types are matched case-sensitively (lowercase per
/// IANA convention); subtypes allow mixed case to keep historical
/// names like `application/JSON` matchable.
///
/// 87th member of the extraction family.
SortLinesResult extractMimeTypesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:application|audio|font|example|image|message|model|'
        r'multipart|text|video)/[A-Za-z0-9][A-Za-z0-9.\-+]*\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Kubernetes resource reference (`kind/name`) from
/// each selected line. Useful for kubectl command audits, ops
/// runbook scrapes, and incident-postmortem inventories.
///
/// Recognition: one of the common Kubernetes kinds followed by `/`
/// and a DNS-1123 subdomain-shaped name (lowercase alphanumeric
/// plus `-` and `.`). The kinds recognised are the standard
/// short and long forms:
/// - Workloads: `pod`, `deployment`, `replicaset`, `statefulset`,
///   `daemonset`, `job`, `cronjob`
/// - Networking: `service`, `ingress`, `endpoints`,
///   `networkpolicy`
/// - Config + storage: `configmap`, `secret`,
///   `persistentvolume`, `persistentvolumeclaim`
/// - Cluster: `namespace`, `node`
/// - RBAC: `serviceaccount`, `role`, `rolebinding`,
///   `clusterrole`, `clusterrolebinding`
/// - Autoscaling: `horizontalpodautoscaler`
///
/// Matches `pod/web`, `deployment/api-gateway`, `service/db-fe`,
/// `configmap/feature-flags`, etc. The name allows DNS-1123
/// subdomain characters (lowercase, digits, `-`, `.`) but must
/// start and end with an alphanumeric (enforced via boundary
/// classes on the regex).
///
/// Singular kinds only — `pods` / `deployments` (plurals) are
/// not matched. kubectl's `kind/name` resource shorthand is
/// canonically singular.
///
/// 88th member of the extraction family.
SortLinesResult extractKubernetesResourcesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:pod|deployment|replicaset|statefulset|daemonset|'
        r'job|cronjob|service|ingress|endpoints|networkpolicy|'
        r'configmap|secret|persistentvolume|persistentvolumeclaim|'
        r'namespace|node|serviceaccount|role|rolebinding|'
        r'clusterrole|clusterrolebinding|horizontalpodautoscaler)'
        r'/[a-z0-9](?:[a-z0-9.\-]*[a-z0-9])?\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every time-of-day substring from each selected line.
/// Useful for meeting-note triage, log-line scraping, and
/// scheduling audits ("which timestamps does this page mention?").
///
/// Recognition (all three forms supported):
/// - 24-hour HH:MM       — e.g. `09:30`, `23:59`
/// - 24-hour HH:MM:SS    — e.g. `09:30:45`
/// - 12-hour HH:MM AM/PM — e.g. `2:30 PM`, `9:30am`, `12:34 P.M.`
///   is NOT supported (no period); the meridian is a single
///   case-insensitive `am` / `pm` token, with optional space.
///
/// The hours and minutes use `\d{1,2}` / `\d{2}` — no semantic
/// range validation (so a pathological `25:99` would also match,
/// but those don't appear in real text in any meaningful way).
/// Word boundaries `\b` keep `1:23` matchable but reject embedded
/// runs inside longer numeric strings like `12345`.
///
/// Distinct from [extractIsoDatesFromLinesIn] (calendar-date
/// shape, M1062) — different time surface.
///
/// 27th member of the extraction family.
SortLinesResult extractTimeOfDayFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?[ap]m)?\b` — the
      // meridian is matched case-insensitively via the `i` flag.
      final re = RegExp(
        r'\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?[ap]m)?\b',
        caseSensitive: false,
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every percentage substring from each selected line.
/// Useful for finance / analytics doc audits — "what numbers
/// is this report citing?", growth-rate harvests, KPI scrapes.
///
/// Recognition: `\b\d+(?:\.\d+)?%`
/// - Word boundary before the digits, so `n=42%` matches but
///   `abc42%` does not.
/// - Optional decimal part (`99.9%`, `0.5%`, `100%` all match).
/// - Literal trailing `%`.
///
/// The whole token (including `%`) is captured — keeps the
/// semantic intent visible in the output. Strip `%` downstream
/// if you want the bare numbers.
///
/// 28th member of the extraction family.
SortLinesResult extractPercentagesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b\d+(?:\.\d+)?%');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every currency-amount substring from each selected line.
/// Useful for finance / pricing doc audits — invoice line items,
/// budget tables, contract amount harvests.
///
/// Supported currency symbols (the four most common):
/// - `$` (US dollar, also CAD/AUD/etc. in context)
/// - `€` (euro)
/// - `£` (British pound)
/// - `¥` (Japanese yen / Chinese yuan)
///
/// Recognition: `[\$€£¥]\d+(?:,\d{3})*(?:\.\d+)?`
/// - Single currency symbol prefix.
/// - At least one digit.
/// - Optional groups of `,\d{3}` for US-style thousands
///   (e.g. `$1,234,567`).
/// - Optional decimal part (`$10.99`).
///
/// EU-style decimal-comma forms like `€5,99` only capture `€5`
/// (the `,99` doesn't follow the thousands `,\d{3}` rule).
/// Multi-char prefixes (`R$`, `HK$`, `C$`) are out of scope —
/// only the dominant single-symbol form is supported.
///
/// 29th member of the extraction family.
SortLinesResult extractCurrencyFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'[\$€£¥]\d+(?:,\d{3})*(?:\.\d+)?');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every file-size substring from each selected line.
/// Useful for log triage, disk-usage audits, asset inventory
/// scrapes — anywhere a doc cites byte counts.
///
/// Recognition: `\b\d+(?:\.\d+)?\s?[KMGTP]?i?B\b` (case-
/// insensitive)
/// - Number with optional decimal (`512`, `1.5`, `42.5`).
/// - Optional single whitespace between number and unit.
/// - Decimal-prefix family `KB MB GB TB PB`, the corresponding
///   binary-prefix `KiB MiB GiB TiB PiB`, or bare `B` for
///   bytes. All combinations match case-insensitively, so
///   `42kb`, `1.5Mb`, `2GiB`, and `512 B` all work.
/// - Word boundaries on each end keep `1.5MB` matchable but
///   reject embedded slices inside longer tokens.
///
/// The whole token (number + optional space + unit) is
/// captured. Caveat: a bare `B` after a number (e.g. `42B`)
/// matches as "42 bytes" — false-positive risk in contexts
/// where `B` means something else (hex literal suffix, etc.).
/// Acceptable for v1.
///
/// 30th member of the extraction family — the round number.
SortLinesResult extractFileSizesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b\d+(?:\.\d+)?\s?[KMGTP]?i?B\b',
        caseSensitive: false,
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every git-short-SHA substring from each selected line.
/// Useful for dev-log scraping, PR-description audits, and
/// commit-list mining ("which commits does this doc reference?").
///
/// Recognition: `\b(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b`
/// - 7 to 40 lowercase hex chars (git's default short-SHA is 7;
///   full SHA-1 is 40).
/// - Lookahead `(?=[0-9a-f]*[a-f])` requires AT LEAST ONE
///   letter — this distinguishes `abc1234` (a SHA) from
///   `1234567` (a plain number that happens to have 7 digits).
/// - Lowercase only — git uses lowercase consistently. Mixed-
///   case `DeadBeef` does NOT match (helps disambiguate from
///   UUIDs and hex colors which often use uppercase).
/// - Word boundaries on each end reject embedded slices and
///   also reject runs longer than 40 (the trailing word boundary
///   would fall inside a word).
///
/// Distinct from M1069 UUIDs (dashed form) and M1063 hex colors
/// (3 / 6 chars, `#` prefix).
///
/// 31st member of the extraction family.
SortLinesResult extractGitShasFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every E.164-ish international phone number from
/// each selected line. Useful for contact-info harvesting,
/// directory audits, and "which phone numbers does this doc
/// cite?" scrapes.
///
/// Recognition: `(?<!\w)\+\d{1,3}(?:[\s\-.]?\d){6,14}`
/// - `+` literal opener with lookbehind `(?<!\w)` blocking
///   matches embedded in word context (so `bob+15551234567@`
///   email local-parts are NOT mis-captured as phones).
/// - Country code: 1 to 3 leading digits after `+`.
/// - 6 to 14 more digits, each optionally preceded by a
///   single whitespace, dash, or period separator. This
///   captures common formattings:
///     `+15551234567` (no separators)
///     `+1-555-123-4567` (dashes)
///     `+1.555.123.4567` (dots)
///     `+44 20 1234 5678` (spaces)
///
/// Strict E.164 caps total digits at 15; this regex allows up
/// to 17 to be tolerant of formatting irregularities (extra
/// digits in extensions, fax-number suffixes, etc.). Acceptable
/// for v1.
///
/// Forms without the `+` prefix (`(555) 123-4567` US-style,
/// `555-1234`) are out of scope — the `+` is the canonical
/// internationalization marker and disambiguates from row
/// references, math expressions, etc.
///
/// 32nd member of the extraction family.
SortLinesResult extractPhoneNumbersFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<!\w)\+\d{1,3}(?:[\s\-.]?\d){6,14}');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Canonicalize every markdown horizontal-rule line in the
/// selected text to `---`. Useful for cleanup before publishing:
/// a doc that mixes `---`, `***`, `___`, and `- - -` gets a
/// uniform divider style in one pass.
///
/// Recognition (CommonMark HR): three or more of `-`, `*`, or
/// `_` chars at line start (allowing optional leading whitespace
/// and any whitespace between the markers, but no other content
/// on the line). All these match:
///   `---`     `***`     `___`
///   `----`    `* * *`   `- - -`
///   `  ---`   `--- `
///
/// Non-HR lines (text, headings, list items) pass through
/// unchanged. The transform is "normalize HR style" rather
/// than extract, so the line count is preserved.
SortLinesResult canonicalizeHorizontalRulesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `^\s*([-*_])(?:\s*\1){2,}\s*$` — at least 3 of the
      // same marker char, separated by optional whitespace,
      // surrounded by optional outer whitespace, nothing else
      // on the line. The backref `\1` enforces consistency
      // (a mixed `-*-` line is NOT an HR).
      final re = RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$');
      return [
        for (final l in lines) if (re.hasMatch(l)) '---' else l,
      ];
    });

/// Extract the URL from every markdown reference-link
/// definition line on each selected line. CommonMark allows
/// reusable link refs defined as `[label]: url`, optionally
/// with a `"title"` suffix; the definition lives on its own
/// line and is later referenced inline as `[text][label]` or
/// shortcut `[label]`.
///
/// Useful for harvesting every reference URL for a link audit
/// ("do they still resolve?"), site-wide URL inventory, and
/// link-rot triage.
///
/// Recognition: `^\s*\[[^\]\n]+\]:\s+(\S+)(?:\s+"[^"\n]*")?\s*$`
/// - Optional leading whitespace (CM permits up to 3 spaces).
/// - Literal `[`, label content (any non-`]`, non-newline
///   chars), literal `]:`, at least one whitespace.
/// - URL: any run of non-whitespace chars (captured).
/// - Optional title: whitespace + `"…"`.
/// - Trailing whitespace tolerated; the line must contain
///   only the definition shape.
///
/// Angle-bracket URL form `<https://x.test>` is captured
/// verbatim (with the brackets); trim them downstream if you
/// want just the URL contents.
///
/// Distinct from M1066 `extractMarkdownLinkUrlsFromLinesIn`
/// (inline `[text](url)` shape). 33rd member of the extraction
/// family.
SortLinesResult extractMarkdownReferenceLinkUrlsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'^\s*\[[^\]\n]+\]:\s+(\S+)(?:\s+"[^"\n]*")?\s*$',
      );
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract the LABEL from every markdown reference-link
/// definition line on each selected line (`[label]: url` →
/// `label`). Companion to
/// [extractMarkdownReferenceLinkUrlsFromLinesIn] (M1094) —
/// paired output enables a "labels vs URLs" cross-check:
/// orphan refs (defined but never used), missing defs
/// (referenced but undefined), duplicate labels.
///
/// Recognition mirrors M1094 (same line shape, same indent
/// tolerance, same title support); only the captured group
/// differs — this transform pulls the bracketed label rather
/// than the URL.
///
/// Labels with internal spaces are CommonMark-legal
/// (`[Click here]: url`) and pass through intact.
///
/// 34th member of the extraction family.
SortLinesResult extractMarkdownReferenceLinkLabelsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'^\s*\[([^\]\n]+)\]:\s+\S+(?:\s+"[^"\n]*")?\s*$',
      );
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract every cell from every markdown-table row line on
/// each selected line. Useful for harvesting table data into
/// a flat list — feeding a downstream sort / dedupe / search,
/// converting table values into a CSV-style stream, etc.
///
/// Recognition (per line):
/// - Trimmed line must start with `|` AND end with `|` (outer
///   pipes are required in this v1; CommonMark's no-outer-pipe
///   form is out of scope).
/// - At least 3 pipes total (so the line has at least 2 cells).
/// - Inner cell content extracted between the pipes; each
///   cell is trimmed.
///
/// Separator rows (`|---|---|`) ARE extracted as cells —
/// each `---` becomes a separate output line. Filter
/// downstream with another transform if you want to skip
/// them; not filtering them keeps the extractor's row-
/// count semantics straightforward.
///
/// 35th member of the extraction family.
SortLinesResult extractMarkdownTableCellsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final out = <String>[];
      for (final l in lines) {
        final trimmed = l.trim();
        if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) {
          continue;
        }
        final pipeCount = '|'.allMatches(trimmed).length;
        if (pipeCount < 3) continue;
        final cells = trimmed.split('|');
        // First and last are empty (leading/trailing pipe);
        // emit only the inner cells, each trimmed.
        for (var i = 1; i < cells.length - 1; i++) {
          out.add(cells[i].trim());
        }
      }
      return out;
    });

/// Extract every IPv4 dotted-quad address from each selected line
/// (`a.b.c.d` where each octet is 0..255). Useful for triaging log
/// paste-ins or surveying which hosts appear in a debug dump.
///
/// Recognition validates each octet's numeric range, so `999.0.0.0`
/// is REJECTED even though it has the right shape. The `\b`
/// boundary on either end prevents matches inside longer dotted
/// runs like a version string `1.2.3.4.5`.
SortLinesResult extractIpv4FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Each octet alternation explicit: 0-9 / 10-99 / 100-199 /
      // 200-249 / 250-255. Ugly but exact.
      const octet =
          r'(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)';
      final re = RegExp(r'\b' + octet + r'(?:\.' + octet + r'){3}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every CSS-shaped hex color code from each selected line:
/// `#RGB`, `#RRGGBB`, `#RGBA`, `#RRGGBBAA`. Useful for pulling a
/// palette out of design notes / CSS dumps for migration into a
/// theme file.
///
/// Recognition: `#` immediately followed by 3, 4, 6, or 8 hex
/// digits. Case-insensitive on the digits (both `#fff` and `#FFF`
/// match). Adjacent hex chars beyond the canonical lengths are
/// rejected — `#fff123` would match as `#fff123` (a valid 6-char
/// code), not as `#fff` + leftover.
SortLinesResult extractHexColorsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Order matters in the alternation: longest forms first so the
      // regex doesn't shortcircuit on the 3-char shape inside an
      // 8-char value.
      final re = RegExp(
        r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every bare ULID (`[0-9A-Z]{26}`) from each selected line
/// and emit them one-per-line. Distinct from
/// [extractWikilinksFromLinesIn] which only catches ULIDs inside
/// `[[...]]` brackets; this one catches loose / inline ULIDs in
/// prose too — useful when a paste-in carries page identifiers
/// without the wikilink chrome.
///
/// Recognition: 26 consecutive Crockford-base32 chars (digits +
/// uppercase letters). Negative lookbehind/lookahead on
/// alphanumeric so embedded ULIDs in longer tokens aren't matched
/// (`prefix01HABC...` would never collide on the 26-char run).
SortLinesResult extractUlidsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<![A-Z0-9])[0-9A-Z]{26}(?![A-Z0-9])');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every ISO-shaped date (`YYYY-MM-DD`) from each selected
/// line and emit them one-per-line in original order. Useful for
/// harvesting timestamps out of meeting notes or journals into a
/// flat date list for follow-on sort / dedupe / range analysis.
///
/// Recognition is conservative: 4-digit year, 2-digit month, 2-digit
/// day, separated by `-`. Doesn't validate the date is real
/// (`2026-02-31` will be extracted) — that's the caller's problem
/// at parse time, not the extractor's.
SortLinesResult extractIsoDatesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\d{4}-\d{2}-\d{2}');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract the BODY of every GFM CHECKED-todo line in the
/// selection (`- [x] foo` → `foo`). Mirror of
/// [extractOpenTodoBodiesIn] — same marker / indent recognition,
/// but the `x` (or `X`) inside the brackets identifies done items.
/// Useful for harvesting "what got done" lists out of a meeting
/// note for a retro / status update.
SortLinesResult extractDoneTodoBodiesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `[xX]` because some editors uppercase the mark; both are
      // valid GFM.
      final re = RegExp(r'^[ \t]*[-*+] \[[xX]\] (.*)$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Extract the BODY of every GFM unchecked-todo line in the
/// selection (`- [ ] foo bar` → `foo bar`). The marker (with any
/// leading indentation) is stripped; the body passes through.
/// Lines that don't start with `- [ ] ` / `* [ ] ` / `+ [ ] ` (with
/// optional leading indent) are dropped from the output — the
/// gesture is "give me the open-todo bodies, not the rows around
/// them".
///
/// Useful for harvesting open action items out of a meeting-note
/// or retro page into a flat to-do list.
SortLinesResult extractOpenTodoBodiesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `^[indent]<bullet> [ ] ` then capture the rest of the line.
      final re = RegExp(r'^[ \t]*[-*+] \[ \] (.*)$');
      final out = <String>[];
      for (final l in lines) {
        final m = re.firstMatch(l);
        if (m != null) out.add(m.group(1)!);
      }
      return out;
    });

/// Split each selected line on whitespace runs, emitting one word
/// per output line. Empty / whitespace-only lines drop out. Useful
/// for word-level processing (sort, dedupe, count) starting from
/// flowing prose. Natural inverse of `joinLinesWithSpace` (M991)
/// on the dimension of "1 line ↔ N words".
SortLinesResult splitOnSpacesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final ws = RegExp(r'\s+');
      final out = <String>[];
      for (final l in lines) {
        for (final w in l.trim().split(ws)) {
          if (w.isNotEmpty) out.add(w);
        }
      }
      return out;
    });

/// Collapse runs of identical consecutive lines, prefixing each
/// kept line with its count — Unix `uniq -c` semantics. The count
/// is right-padded to the width of the largest count so columns
/// stay aligned. Non-consecutive recurrences each get their own
/// entry with their own run-count.
///
///   'foo\nfoo\nfoo\nbar\nfoo\n'  →  '3 foo\n1 bar\n1 foo\n'
///
/// Useful for log analysis: spot which events spammed in a row
/// vs. which fired only once. Companion to
/// [collapseConsecutiveDuplicatesIn] (which strips the run but
/// loses the count).
SortLinesResult countConsecutiveDuplicatesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      if (lines.isEmpty) return lines;
      // First pass: collect (count, value) tuples for each run.
      final runs = <(int, String)>[];
      var run = 1;
      for (var i = 1; i < lines.length; i++) {
        if (lines[i] == lines[i - 1]) {
          run++;
        } else {
          runs.add((run, lines[i - 1]));
          run = 1;
        }
      }
      runs.add((run, lines.last));
      // Width of the largest count to align the column.
      final width = runs
          .map((r) => r.$1.toString().length)
          .reduce((a, b) => a > b ? a : b);
      return [
        for (final r in runs) '${r.$1.toString().padLeft(width)} ${r.$2}',
      ];
    });

/// Collapse runs of identical consecutive lines down to a single
/// occurrence — Unix `uniq` semantics. Non-consecutive duplicates
/// are KEPT. Case-sensitive, matches the existing dedupe family
/// convention.
///
/// Differs from [dedupeLinesIn] which removes ALL duplicates
/// regardless of position. Use this when consecutive duplicates
/// are noise (a log file that emitted the same line three times
/// in a row) but non-consecutive recurrences are meaningful (the
/// same status reported across separate sessions).
SortLinesResult collapseConsecutiveDuplicatesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      if (lines.isEmpty) return lines;
      final out = <String>[lines.first];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i] != lines[i - 1]) out.add(lines[i]);
      }
      return out;
    });

/// Remove consecutive AND non-consecutive duplicate lines in the
/// selected block, keeping the FIRST occurrence of each. Case-
/// sensitive — Notion / Vim convention.
SortLinesResult dedupeLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final seen = <String>{};
      return [for (final l in lines) if (seen.add(l)) l];
    });

/// Reverse the order of the lines in the selected block. Useful for
/// flipping a sort or rendering a list bottom-up.
SortLinesResult reverseLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) => lines.reversed.toList());

/// Wrap each non-blank selected line in `**…**` so its contents
/// render bold. Blank lines stay blank.
SortLinesResult boldLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '**$l**',
      ];
    });

/// Wrap each non-blank selected line in `*…*` so its contents
/// render italic. Blank lines stay blank.
SortLinesResult italicLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '*$l*',
      ];
    });

/// Wrap each non-blank selected line in `` `…` `` so its contents
/// render as inline code. Blank lines stay blank.
SortLinesResult codeLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '`$l`',
      ];
    });

/// Wrap each non-blank selected line in `~~…~~` (GFM strikethrough).
/// Blank lines stay blank.
SortLinesResult strikethroughLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '"$l"',
      ];
    });

/// JSON-encode each selected line as a string literal. Uses
/// `dart:convert`'s `jsonEncode` so all escape rules (`"` → `\"`,
/// `\` → `\\`, control chars → `\uXXXX` or named escapes) are
/// applied correctly.
///
/// Stricter than [quoteLinesIn] (which only wraps with `"…"` and
/// preserves internal `"` verbatim — producing invalid JSON if
/// the source contains a quote). This transform produces output
/// suitable for direct JSON-array construction: pipe through
/// `joinLinesWithComma` and wrap with `[…]` for a ready-to-paste
/// JSON array.
///
/// Blank-line passthrough mirrors the other "wrap each line"
/// transforms (`quoteLines`, `bold`, `italic`).
SortLinesResult jsonStringEncodeLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else jsonEncode(l),
      ];
    });

/// Compute the arithmetic mean of every selected line that parses
/// as a number. Non-numeric lines are skipped. Always returns a
/// fixed-point result (means generally aren't whole numbers, so we
/// don't bother trying to detect that case). Returns the source
/// unchanged when no line parses as a number.
SortLinesResult averageNumericLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toSnakeCase(l),
      ];
    });

/// Per-line wrapper for [toCamelCase].
SortLinesResult camelCaseLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toConstantCase(l),
      ];
    });

/// Convert a single line into `kebab-case` — same split rules as
/// [toSnakeCase] but the word separator is `-` instead of `_`.
/// Common for URL slugs, file names, CSS class names, and most
/// command-line flag conventions.
///
///   "My Cool Title!" → "my-cool-title"
///   "hello_world"    → "hello-world"
///   "v1.2.3 final"   → "v1-2-3-final"
String toKebabCase(String line) => toSnakeCase(line).replaceAll('_', '-');

/// Per-line wrapper for [toKebabCase].
SortLinesResult kebabCaseLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else toKebabCase(l),
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      final shuffled = [...lines]..shuffle(random);
      return shuffled;
    });

/// Split each selected line on sentence boundaries AND prefix every
/// resulting sentence with `- `. The composite "paragraph → bullet
/// list" transform that pairs naturally with M990's
/// `splitLinesOnSentencesIn` but emits a bulleted list rather than
/// plain lines. Useful for converting flowing prose into proofread-
/// ready bullet form. Lines without a sentence boundary still get
/// the bullet prefix.
SortLinesResult bulletizeSentencesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final boundary = RegExp(r'(?<=[.!?])\s+(?=[A-Z])');
      return [
        for (final l in lines)
          if (boundary.hasMatch(l))
            ...l
                .split(boundary)
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => '- $s')
          else if (l.trim().isEmpty)
            l
          else
            '- ${l.trim()}',
      ];
    });

/// Split each selected line on **sentence boundaries**, emitting one
/// sentence per output line. A boundary is a sentence terminator
/// (`.`, `!`, `?`) followed by whitespace and an uppercase letter —
/// good enough to handle plain prose without false-firing on the
/// `Dr. Smith` shape (no capital follows the period inside the
/// abbreviation, just the abbreviated name itself).
///
/// Useful for "split a paragraph into one-sentence-per-line" proof-
/// reading mode; pair with `joinLineWithNext` / similar to rebuild.
/// Lines without a boundary pass through unchanged.
///
///   "Hello world. Goodbye now."  →  "Hello world."
///                                   "Goodbye now."
SortLinesResult splitLinesOnSentencesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Split on a positive lookbehind/lookahead pair — keeps the
      // terminator attached to the LEFT sentence while requiring the
      // RIGHT sentence to start with a capital letter (so `Dr. Smith`
      // stays one sentence — no capital follows the abbreviation's
      // period until "Smith" starts, but the regex sees `.` + ` ` +
      // `S` here too — accept the false positive, it's the better
      // failure mode than splitting nowhere).
      final boundary = RegExp(r'(?<=[.!?])\s+(?=[A-Z])');
      return [
        for (final l in lines)
          if (boundary.hasMatch(l))
            ...l.split(boundary).map((s) => s.trim()).where((s) => s.isNotEmpty)
          else
            l,
      ];
    });

/// Trim BOTH leading and trailing whitespace from every line in the
/// selected block — a single op that combines `stripLeadingWhitespace`
/// (M821 era) and `trimTrailingWhitespace`. Useful when prose lost
/// its surrounding whitespace structure and you want to flatten it
/// in one shot. Blank lines stay blank.
SortLinesResult trimWhitespaceLinesIn(String text, int start, int end) =>
    transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) l.trim()],
    );

/// Strip trailing whitespace (spaces, tabs) from every line in the
/// selected block. Common cleanup before committing — many tools
/// reject trailing whitespace and it's invisible in the editor.
SortLinesResult trimTrailingWhitespaceIn(String text, int start, int end) =>
    transformLinesIn(
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(
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
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines) if (l.trim().isEmpty) l else '// $l',
      ];
    });

/// Wrap each non-blank selected line in `<!-- … -->`. Useful for
/// hiding notes in markdown bodies (commented-out content is
/// invisible in the rendered view but stays in the source).
/// Blank lines stay blank.
SortLinesResult htmlCommentLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          if (l.trim().isEmpty) l else '<!-- $l -->',
      ];
    });

/// Inverse of [htmlCommentLinesIn]: strip the `<!-- … -->` wrapper
/// from every line where it fully wraps the line. Non-matching
/// lines pass through.
SortLinesResult htmlUncommentLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
      final internalRun = RegExp(r'(?<=\S)[ \t]{2,}');
      return [
        for (final l in lines) l.replaceAll(internalRun, ' '),
      ];
    });

/// Wrap each selected line at an 80-character column boundary,
/// breaking on the last whitespace at or before column 80 so words
/// don't get cut. Lines shorter than 80 chars pass through. Words
/// longer than 80 chars on their own — URLs, hashed names — stay
/// intact because the alternative (mid-word break) hurts more than
/// the long line does.
///
/// Useful when pasting in prose written without explicit wrapping
/// (e.g. word-processor exports or LLM output). Per-line scope: a
/// blank-line-separated paragraph isn't re-flowed across the blank
/// line; each non-blank line is wrapped on its own.
SortLinesResult wrapLinesAt80In(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      const width = 80;
      List<String> wrap(String l) {
        if (l.length <= width) return [l];
        final out = <String>[];
        var s = l;
        while (s.length > width) {
          // Find the last whitespace at or before column `width`.
          var brk = -1;
          for (var i = width; i >= 0; i--) {
            final c = s.codeUnitAt(i);
            if (c == 0x20 || c == 0x09) {
              brk = i;
              break;
            }
          }
          if (brk <= 0) {
            // No word boundary at/before column 80 — find the next
            // space anywhere (don't slice mid-word). If there's no
            // space at all, give up and emit the line as-is.
            brk = s.indexOf(RegExp(r'[ \t]'));
            if (brk < 0) {
              out.add(s);
              return out;
            }
          }
          out.add(s.substring(0, brk));
          s = s.substring(brk + 1);
        }
        out.add(s);
        return out;
      }
      return [for (final l in lines) ...wrap(l)];
    });

/// Prefix every selected line with its character count, padded to
/// the width of the longest count so columns stay aligned:
/// `[ 4] foo` / `[12] hello world`. Useful for spotting long-line
/// outliers when proofing prose, or for sanity-checking that a list
/// of identifiers / IDs has a consistent width.
///
/// Inverse of [stripLeadingNumberPrefixIn] (which strips `1. ` /
/// `1) ` / etc.) — the bracketed form isn't matched by the strip
/// regex, so accidental round-trips don't happen. Blank lines get
/// `[ 0]` so position information is preserved.
SortLinesResult prefixLinesWithCharCountIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      if (lines.isEmpty) return lines;
      final width = lines
          .map((l) => l.length.toString().length)
          .reduce((a, b) => a > b ? a : b);
      return [
        for (final l in lines)
          '[${l.length.toString().padLeft(width)}] $l',
      ];
    });

/// Prefix every selected line with its **word count**, padded to the
/// width of the longest count so the column stays aligned:
/// `[ 3] one two three`. Whitespace-separated runs, matching the
/// convention from `sortLinesByWordCount` and the text-stats footer.
/// Blank lines get `[0]` so position information is preserved.
///
/// Companion to [prefixLinesWithCharCountIn] (M1009) for prose where
/// word count matters more than character count.
SortLinesResult prefixLinesWithWordCountIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      if (lines.isEmpty) return lines;
      int wc(String s) =>
          s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;
      final width = lines
          .map((l) => wc(l).toString().length)
          .reduce((a, b) => a > b ? a : b);
      return [
        for (final l in lines)
          '[${wc(l).toString().padLeft(width)}] $l',
      ];
    });

/// Strip a leading bracketed char-count prefix from every selected
/// line: `[12] hello world` → `hello world`. Matches the exact shape
/// emitted by [prefixLinesWithCharCountIn] (optional padding spaces
/// inside the brackets, then a single space). Lines without that
/// prefix pass through unchanged. Inverse round-trips cleanly with
/// the prefix op.
SortLinesResult stripLeadingCharCountPrefixIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // ` *` allows the left-padding the prefix op adds when counts
      // have mixed widths (e.g. `[ 5]` next to `[12]`).
      final re = RegExp(r'^\[ *\d+\] ');
      return [for (final l in lines) l.replaceFirst(re, '')];
    });

/// Add a two-space indent to the start of every selected line.
/// Mirrors VS Code's Tab-with-multi-line-selection gesture. Empty
/// lines are left blank — indenting them would add only trailing
/// whitespace, which the user typically wants stripped, not added.
SortLinesResult indentLinesIn(String text, int start, int end) =>
    transformLinesIn(
      text,
      start,
      end,
      (lines) => [for (final l in lines) l.isEmpty ? l : '  $l'],
    );

/// Strip up to two leading spaces (one indent level) from every
/// selected line. Inverse of [indentLinesIn]; mirrors VS Code's
/// Shift-Tab gesture. Lines with one leading space lose just that
/// one; lines flush at column 0 stay flush. Leading tabs are
/// preserved (the tab/space mix is `tabsToSpaces`'s concern).
SortLinesResult outdentLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      String stripOne(String l) {
        if (l.startsWith('  ')) return l.substring(2);
        if (l.startsWith(' ')) return l.substring(1);
        return l;
      }
      return [for (final l in lines) stripOne(l)];
    });

/// Strip leading whitespace (spaces, tabs) from every line in the
/// selected block. The trim-trailing's mirror — common when pasting
/// pre-indented code into the editor and wanting a clean left margin.
SortLinesResult stripLeadingWhitespaceIn(String text, int start, int end) =>
    transformLinesIn(
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
  return transformLinesIn(
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
    transformLinesIn(
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
    transformLinesIn(
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(
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
    transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) rot13(l)],
    );

/// URL-encode every non-blank selected line via `Uri.encodeComponent`
/// so the value is safe to drop into a query string or path segment
/// (spaces become `%20`, slashes `%2F`, etc.). Blank lines stay blank
/// so block structure is preserved.
SortLinesResult urlEncodeLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(
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
    transformLinesIn(
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

/// Format a [DateTime] as the ISO 8601 year-week tag used by the
/// `/week` slash entry (e.g. `2026-W20`). The week number follows
/// the ISO 8601 rule: week 1 is the week containing the first
/// Thursday of the year, weeks start on Monday, and some years span
/// 53 weeks. The year portion is the **ISO week-numbering year** —
/// usually the calendar year, but on late-December or early-January
/// dates it can roll over (e.g. `2026-01-01` falls in `2026-W01`,
/// but `2027-01-01` would fall in `2026-W53` since 2026 is a 53-week
/// year). That subtle reroll matters when filing weekly notes near
/// the year boundary.
String formatIsoYearWeek(DateTime when) {
  // Step to the Thursday of the same ISO week — that anchors the
  // year/week pair unambiguously (because weeks are defined by which
  // Thursday they contain).
  final thursday =
      when.add(Duration(days: DateTime.thursday - when.weekday));
  // First Thursday of `thursday`'s calendar year is week 1 by
  // definition. weekday 1..7; (4 - jan1.weekday + 7) % 7 == days
  // until the first Thursday of the year.
  final jan1 = DateTime(thursday.year, 1, 1);
  final daysToFirstThursday = (DateTime.thursday - jan1.weekday + 7) % 7;
  final firstThursday = jan1.add(Duration(days: daysToFirstThursday));
  final week =
      (thursday.difference(firstThursday).inDays ~/ 7) + 1;
  final yyyy = thursday.year.toString().padLeft(4, '0');
  final ww = week.toString().padLeft(2, '0');
  return '$yyyy-W$ww';
}

/// Format a [DateTime] as the `YYYY-Qn` quarter tag used in the sample
/// vault's QBR notes (e.g. `2026-Q2`). Quarter boundaries follow the
/// standard calendar definition: Q1 = Jan–Mar, Q2 = Apr–Jun,
/// Q3 = Jul–Sep, Q4 = Oct–Dec.
String formatYearQuarter(DateTime when) {
  final yyyy = when.year.toString().padLeft(4, '0');
  final q = ((when.month - 1) ~/ 3) + 1;
  return '$yyyy-Q$q';
}

/// Format a [DateTime] as a session-checkpoint block used by the
/// `/checkpoint` slash entry: a markdown horizontal rule, a bolded
/// timestamp on its own line, and an empty body line where the
/// caret lands ready to type. Held as a function so the slash
/// dispatch stays one line.
String formatCheckpointBlock(DateTime when) =>
    '---\n**${formatTimestamp(when)}**\n\n';

/// Format a [DateTime] as the `YYYY-MM` year-month tag used by the
/// monthly-review slash entry (e.g. `2026-05`).
String formatYearMonth(DateTime when) {
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  return '$yyyy-$mm';
}

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
    transformLinesIn(text, start, end, (lines) {
      final cells =
          [for (final l in lines) l.trim()].where((l) => l.isNotEmpty).toList();
      if (cells.isEmpty) return lines;
      return [cells.join(', ')];
    });

/// Join every non-blank selected line into a single space-separated
/// paragraph. Each line is trimmed before joining so trailing
/// whitespace from a sentence split doesn't leak into the rebuilt
/// prose. Natural inverse of [splitLinesOnSentencesIn] (M990) for
/// rebuilding after proofreading. Returns the source unchanged when
/// the block has no non-blank lines.
SortLinesResult joinLinesWithSpaceIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      final cells =
          [for (final l in lines) l.trim()].where((l) => l.isNotEmpty).toList();
      if (cells.isEmpty) return lines;
      return [cells.join(' ')];
    });

/// Split every selected line on `,` (with optional trailing
/// whitespace) into separate lines. Inverse of [joinLinesWithCommaIn].
/// Each split cell is trimmed. Lines without a comma pass through.
SortLinesResult splitOnCommaIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
  return transformLinesIn(
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

/// Strip every non-ASCII character from each selected line.
/// Keeps the ASCII range (`U+0000`–`U+007F`) intact and drops
/// everything else: emoji, accented Latin, CJK ideographs, smart
/// quotes, em dashes — all gone. Useful for normalizing prose for
/// systems that don't handle Unicode (legacy log pipelines, plain-
/// text exports, ASCII-only databases).
///
/// More aggressive than `removeAccents` (M993 — folds Latin
/// diacritics to their ASCII base letter) and `stripEmoji`
/// (M992 — only the pictograph blocks). This one drops EVERYTHING
/// outside the 0–127 codepoint range.
SortLinesResult asciiOnlyLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final buf = StringBuffer();
            for (var i = 0; i < l.length; i++) {
              final c = l.codeUnitAt(i);
              if (c < 128) buf.writeCharCode(c);
            }
            return buf.toString();
          })(),
      ];
    });

/// Capitalize the first letter of each selected line, leaving the
/// rest of the line untouched. Mirrors the "start each bullet with
/// a capital" copy-edit gesture. Differs from `titleCaseLinesIn`
/// (which capitalizes every non-small word) and
/// `sentenceCaseLinesIn` (which lowercases the rest after the first
/// letter). Useful as a lighter-touch first-pass cleanup.
SortLinesResult capitalizeFirstLetterPerLineIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      String cap(String l) {
        // Find the first cased character (skip indentation /
        // punctuation) so a bullet's body gets the cap, not the `-`.
        for (var i = 0; i < l.length; i++) {
          final c = l[i];
          if (c == c.toUpperCase() && c == c.toLowerCase()) continue;
          return '${l.substring(0, i)}${c.toUpperCase()}${l.substring(i + 1)}';
        }
        return l;
      }
      return [for (final l in lines) cap(l)];
    });

/// Uppercase every line in the selected block. Common power-user
/// transform; mirrors VS Code's "Transform to Uppercase".
SortLinesResult uppercaseLinesIn(String text, int start, int end) =>
    transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) l.toUpperCase()],
    );

/// Lowercase every line in the selected block.
SortLinesResult lowercaseLinesIn(String text, int start, int end) =>
    transformLinesIn(
      text, start, end, (lines) => [for (final l in lines) l.toLowerCase()],
    );

/// Prefix every selected line with its 1-based index in the
/// selection, zero-padded to the width of the largest index so the
/// column stays aligned. Blank lines get the prefix too — they
/// count as positions and keep the numbering monotonic. Useful for
/// quickly annotating a paste-in with positional markers without
/// committing to ordered-list syntax (which `renumberListLines`
/// already handles for actual `1. ` lists).
///
///   foo            01. foo
///   bar       →    02. bar
///   baz            03. baz
SortLinesResult prefixLinesWithIndexIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      if (lines.isEmpty) return lines;
      final width = lines.length.toString().length;
      return [
        for (var i = 0; i < lines.length; i++)
          '${(i + 1).toString().padLeft(width, '0')}. ${lines[i]}',
      ];
    });

/// Toggle the case of every cased character on every selected line:
/// uppercase becomes lowercase and vice versa, character-by-character.
/// Non-cased characters (digits, punctuation, whitespace, symbols, and
/// most non-Latin scripts) pass through. Mirrors Notepad++'s "Invert
/// case" and JetBrains' "Toggle case" — running the op twice is the
/// identity for ASCII inputs.
///
///   "Hello World"  →  "hELLO wORLD"
SortLinesResult swapCaseLinesIn(String text, int start, int end) =>
    transformLinesIn(
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
    transformLinesIn(text, start, end, (lines) {
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
/// Strip a leading ATX heading marker (`# `, `## `, `### `,
/// `#### `, `##### `, `###### `) from every selected line that has
/// one. Lines without a heading marker pass through. Leading
/// indentation is preserved — `  ## foo` becomes `  foo`. Useful
/// for converting a heading block back to plain prose without
/// disturbing surrounding bullet / blockquote nesting.
SortLinesResult stripHeadingMarkerLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'^([ \t]*)#{1,6} ');
      return [
        for (final l in lines) l.replaceFirstMapped(re, (m) => m.group(1)!),
      ];
    });

/// Remove the **common leading whitespace** from every line in the
/// selected block — the standard "dedent" semantics. The minimum
/// indent across all non-blank lines is computed, then stripped
/// from each line. Tabs and spaces are treated as equivalent
/// columns of width 1 (the same convention the M1006
/// `outdentLinesIn` uses); the user's tab-vs-space mix is left
/// alone, only the common prefix length is reduced.
///
///   '  foo\n    bar\n  baz\n'  →  'foo\n  bar\nbaz\n'
///
/// Blank lines are skipped when computing the minimum indent but
/// emitted unchanged. Useful when a paste-in came over-indented
/// from being copied out of a nested context.
SortLinesResult dedentLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      int leading(String l) {
        var i = 0;
        while (i < l.length && (l.codeUnitAt(i) == 0x20 || l.codeUnitAt(i) == 0x09)) {
          i++;
        }
        return i;
      }
      var minIndent = -1;
      for (final l in lines) {
        if (l.trim().isEmpty) continue;
        final n = leading(l);
        if (minIndent < 0 || n < minIndent) minIndent = n;
      }
      if (minIndent <= 0) return lines;
      return [
        for (final l in lines)
          l.trim().isEmpty ? l : l.substring(minIndent),
      ];
    });

/// Strip blank lines from the **edges** of the selected block,
/// preserving every line in the interior. Useful for trimming the
/// "extra newlines around a paste" without flattening blank lines
/// that mark paragraph breaks inside the content. Differs from
/// `dropBlankLines` (which removes every blank line) and
/// `collapseBlankLines` (which compresses runs to one).
///
///   '\n\nhello\n\nworld\n\n'  →  'hello\n\nworld\n'
SortLinesResult trimBlankEdgeLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      var lo = 0;
      var hi = lines.length;
      while (lo < hi && lines[lo].trim().isEmpty) {
        lo++;
      }
      while (hi > lo && lines[hi - 1].trim().isEmpty) {
        hi--;
      }
      return lines.sublist(lo, hi);
    });

/// Unconditionally ADD a `> ` blockquote prefix to every selected
/// non-blank line. Idempotent on non-quoted lines (becomes
/// `> ` + original). Blank lines stay blank. Existing leading
/// indentation is preserved — `  foo` becomes `  > foo`.
///
/// Differs from `toggleBlockquotePrefixIn` which strips when ALL
/// lines are quoted. This op always adds, so a user iterating "add
/// more nesting" can repeat the action without the toggle flipping
/// to remove mode partway through.
SortLinesResult addBlockquotePrefixIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            if (l.trim().isEmpty) return l;
            final indent = l.substring(0, l.length - l.trimLeft().length);
            final body = l.substring(indent.length);
            return '$indent> $body';
          })(),
      ];
    });

/// Unconditionally strip a leading `> ` blockquote prefix from
/// every selected line that has one. Lines without the prefix pass
/// through. Differs from [toggleBlockquotePrefixIn] which only
/// strips when ALL non-blank lines start with `> ` — useful when
/// you have a mixed selection (some quoted, some not) and want to
/// unquote the ones that ARE quoted without adding `> ` to the
/// others. Existing leading indentation is preserved (`  > foo`
/// becomes `  foo`).
SortLinesResult stripBlockquotePrefixIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      return [
        for (final l in lines)
          (() {
            final indent = l.substring(0, l.length - l.trimLeft().length);
            final after = l.trimLeft();
            if (!after.startsWith('> ')) return l;
            return '$indent${after.substring(2)}';
          })(),
      ];
    });

SortLinesResult toggleBlockquotePrefixIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
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

  return transformLinesIn(
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

  return transformLinesIn(
    text, start, end, (lines) => [for (final l in lines) titleCaseLine(l)],
  );
}
