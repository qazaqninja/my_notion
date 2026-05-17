/// Pure-Dart detector for the `**X**` bold autoformat trigger.
///
/// Returns the span and inner text when the typed character sequence
/// ending at [caret] has just completed a non-empty bold pattern.
/// Caller (the WYSIWYG `EditReaction` wiring landing in slice 1b) is
/// expected to drive this from a per-keystroke composer listener:
/// when [detectBoldAutoformat] returns non-null, dispatch an Editor
/// command sequence that strips the four `*` characters and applies
/// the `boldAttribution` to the captured inner range.
///
/// Contract:
/// - Last two chars before [caret] must be `**`.
/// - Walking back from `caret-2` there must be a NON-OVERLAPPING `**`
///   opener on the same line, with at least one char between them.
/// - Inner span must not contain a newline.
/// - Returns null for any of the failure modes above + defensive bounds
///   checks (negative caret, caret past end).
({int markerStart, int markerEnd, String inner})? detectBoldAutoformat({
  required String text,
  required int caret,
}) {
  if (caret < 4 || caret > text.length) return null;
  if (text[caret - 1] != '*' || text[caret - 2] != '*') return null;
  // Closing `**` is at [caret-2, caret). Inner candidate ends at
  // caret-2; opener must be a `**` somewhere earlier on the same line.
  final innerEnd = caret - 2;
  // Walk backwards looking for `**` opener. Skip the immediate two
  // chars before innerEnd so `****` doesn't match itself.
  for (var i = innerEnd - 1; i >= 1; i--) {
    final ch = text[i];
    if (ch == '\n') return null; // crossed a line break
    if (ch == '*' && text[i - 1] == '*') {
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
