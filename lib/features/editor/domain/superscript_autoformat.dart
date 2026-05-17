/// Pure-Dart detector for the `^X^` superscript autoformat trigger
/// (Pandoc convention). Sibling of [detectSubscriptAutoformat] but
/// without the strike-collision guard — Quill has no `^^` mark, so
/// `^` is unambiguous as a single-char marker.
///
/// Contract:
/// - `text[caret - 1]` must be `^`.
/// - Walking back from `caret - 2` there must be a single `^` opener
///   on the same line.
/// - Pandoc rule: inner span MUST NOT contain whitespace (including
///   newline) — sub/sup are word-scope only.
/// - Returns null for any of the failure modes above + defensive
///   bounds checks (caret < 3, caret > text.length).
({int markerStart, int markerEnd, String inner})? detectSuperscriptAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 3 || caret > text.length) return null;
  if (text[caret - 1] != '^') return null;
  final innerEnd = caret - 1;
  for (var i = innerEnd - 1; i >= 0; i--) {
    final ch = text[i];
    if (_isWhitespace(ch)) return null;
    if (ch == '^') {
      final openerStart = i;
      final openerEnd = i + 1;
      if (openerEnd >= innerEnd) return null; // empty inner
      final inner = text.substring(openerEnd, innerEnd);
      return (
        markerStart: openerStart,
        markerEnd: caret,
        inner: inner,
      );
    }
  }
  return null;
}

bool _isWhitespace(String ch) =>
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
