/// Pure-Dart detector for the `==X==` highlight autoformat trigger.
/// Near-clone of [detectBoldAutoformat] / [detectStrikeAutoformat]
/// with `=` as the marker char.
///
/// Contract:
/// - Last two chars before [caret] must be `=`.
/// - Walking back from `caret - 2` there must be a non-overlapping
///   `==` opener on the same line, with at least one char between
///   them.
/// - Inner span must not contain a newline.
/// - Returns null for any of the failure modes above + defensive
///   bounds checks (caret < 4, caret > text.length).
({int markerStart, int markerEnd, String inner})?
    detectHighlightAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 4 || caret > text.length) return null;
  if (text[caret - 1] != '=' || text[caret - 2] != '=') return null;
  final innerEnd = caret - 2;
  for (var i = innerEnd - 1; i >= 1; i--) {
    final ch = text[i];
    if (ch == '\n') return null;
    if (ch == '=' && text[i - 1] == '=') {
      final openerStart = i - 1;
      final openerEnd = i + 1;
      if (openerEnd >= innerEnd) return null; // empty inner
      final inner = text.substring(openerEnd, innerEnd);
      if (inner.contains('\n')) return null;
      return (
        markerStart: openerStart,
        markerEnd: caret,
        inner: inner,
      );
    }
  }
  return null;
}
