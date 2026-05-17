/// Pure-Dart detector for the italic autoformat triggers `*X*` and
/// `_X_`. Sister to `detectBoldAutoformat`; runs SECOND in the WYSIWYG
/// reactionPipeline so bold's greedier `**X**` always wins when the
/// patterns overlap.
///
/// Contract:
/// - Last char before [caret] must be `*` or `_`.
/// - For `*` closer: `text[caret-2]` must NOT be `*` (otherwise this is
///   bold's closing `**` and italic must skip).
/// - Walk back for the matching opener of the same marker char.
/// - Opener `*` must NOT be flanked by another `*` (else it's part of
///   a `**` bold run).
/// - Opener `_` must NOT be preceded by a word char (CommonMark intra-
///   word underscore rule — `snake_case` shouldn't auto-italicize).
/// - Inner span must be non-empty, must NOT contain `\n`, and must NOT
///   contain another instance of the marker char.
/// - Defensive bounds: caret < 3 OR caret > text.length → null.
({int markerStart, int markerEnd, String inner})? detectItalicAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 3 || caret > text.length) return null;
  final closer = text[caret - 1];
  if (closer != '*' && closer != '_') return null;

  // Asterisk closer: refuse if the preceding char is also `*` (this
  // closer belongs to a `**` pair — bold's domain).
  if (closer == '*' && text[caret - 2] == '*') return null;

  final innerEnd = caret - 1;
  for (var i = innerEnd - 1; i >= 0; i--) {
    final ch = text[i];
    if (ch == '\n') return null; // crossed line
    if (ch != closer) continue;

    // Asterisk opener: skip if flanked by another `*`.
    if (closer == '*') {
      if (i + 1 < text.length && text[i + 1] == '*') return null;
      if (i > 0 && text[i - 1] == '*') return null;
    }

    // Underscore opener: skip if preceded by a word char.
    if (closer == '_' && i > 0 && _isWordChar(text[i - 1])) {
      return null;
    }

    final openerStart = i;
    final openerEnd = i + 1;
    if (openerEnd >= innerEnd) return null; // empty inner
    final inner = text.substring(openerEnd, innerEnd);
    if (inner.contains('\n') || inner.contains(closer)) return null;
    return (
      markerStart: openerStart,
      markerEnd: caret,
      inner: inner,
    );
  }
  return null;
}

bool _isWordChar(String s) =>
    s.length == 1 &&
    (RegExp(r'[A-Za-z0-9]').hasMatch(s) || s == '_');
