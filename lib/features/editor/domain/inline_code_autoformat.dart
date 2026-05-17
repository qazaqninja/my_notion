/// Pure-Dart detector for the inline code autoformat trigger `` `X` ``.
/// Single-char marker — simpler than italic since there's no flanking
/// rule and no sibling double-char marker to disambiguate.
///
/// Contract:
/// - Last char before [caret] must be a backtick.
/// - Walk back from caret-1 for the matching opener backtick on the
///   same line.
/// - Inner span must be non-empty and must not contain a newline.
///   (It also can't contain a backtick — that backtick would have been
///   picked up as the opener walking back.)
/// - Defensive bounds: caret < 3 or caret > text.length → null.
({int markerStart, int markerEnd, String inner})?
    detectInlineCodeAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 3 || caret > text.length) return null;
  if (text[caret - 1] != '`') return null;
  final innerEnd = caret - 1;
  for (var i = innerEnd - 1; i >= 0; i--) {
    final ch = text[i];
    if (ch == '\n') return null; // crossed line
    if (ch != '`') continue;
    final openerStart = i;
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
  return null;
}
