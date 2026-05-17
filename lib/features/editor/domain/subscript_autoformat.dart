/// Pure-Dart detector for the `~X~` subscript autoformat trigger
/// (Pandoc convention). Sibling of [detectBoldAutoformat] /
/// [detectStrikeAutoformat] etc., but with extra guards against the
/// strike collision (strike uses `~~X~~`).
///
/// Contract:
/// - `text[caret - 1]` must be `~`.
/// - `text[caret - 2]` must NOT be `~` (else this is strike's closer).
/// - Walking back from `caret - 2` there must be a single-`~` opener
///   on the same line (its left and right neighbors must not be `~`).
/// - Pandoc rule: inner span MUST NOT contain whitespace (including
///   newline) — sub/sup are word-scope only.
/// - Returns null for any of the failure modes above + defensive
///   bounds checks (caret < 3, caret > text.length).
({int markerStart, int markerEnd, String inner})? detectSubscriptAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 3 || caret > text.length) return null;
  if (text[caret - 1] != '~') return null;
  // Strike's closer is `~~`. If the char before the closer is also `~`,
  // refuse — this is strike territory.
  if (text[caret - 2] == '~') return null;
  final innerEnd = caret - 1;
  for (var i = innerEnd - 1; i >= 0; i--) {
    final ch = text[i];
    if (_isWhitespace(ch)) return null;
    if (ch == '~') {
      // Opener must be a single `~`: its neighbors must not be `~`.
      if (i > 0 && text[i - 1] == '~') continue;
      if (i + 1 < text.length && text[i + 1] == '~') continue;
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
