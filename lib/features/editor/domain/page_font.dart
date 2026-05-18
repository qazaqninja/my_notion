/// User-visible label for a `font:` frontmatter value, shown in the
/// confirmation toast after Set-font is dispatched. `sans` is the
/// implicit default; the other two map to the bundled font families
/// (`serif` → Georgia, `mono` → JetBrainsMono — see
/// `assets/fonts/`). Unknown values pass through verbatim so a
/// hand-edited frontmatter `font:` value doesn't get re-labelled.
String pageFontLabel(String picked) => switch (picked) {
      'sans' => 'sans-serif (default)',
      'serif' => 'serif',
      'mono' => 'monospace',
      _ => picked,
    };

/// What the AppBar's Set-font handler should do given a picked value
/// and the page's existing `font:` rawScalar (or null when no entry
/// exists). Decouples the dispatch logic from the bloc itself so the
/// no-op detection is unit-testable.
enum PageFontAction {
  /// Picked value matches the effective current font — skip the
  /// dispatch and tell the user nothing changed.
  noop,

  /// User picked the default (`sans`) and an existing entry is in
  /// place — strip the `font:` field back to nothing.
  remove,

  /// No existing `font:` entry — append a fresh one.
  add,

  /// Existing entry with a different value — replace it.
  edit,
}

/// Decide what the Set-font handler should do for a given user pick.
///
/// `picked` is the option the user chose (one of `'sans'`, `'serif'`,
/// `'mono'`, or any custom value a hand-edit might persist).
/// `existing` is the page's current frontmatter `font:` rawScalar
/// (null when absent).
///
/// Rules (mirrors the legacy `_setFont` handler exactly):
/// 1. `picked == 'sans' && existing == null` → noop (already default).
/// 2. `picked == 'sans' && existing != null` → remove.
/// 3. `existing != null && existing.trim() == picked` → noop.
/// 4. `existing == null` → add.
/// 5. otherwise → edit.
PageFontAction pageFontActionFor({
  required String picked,
  required String? existing,
}) {
  if (picked == 'sans') {
    return existing == null ? PageFontAction.noop : PageFontAction.remove;
  }
  if (existing != null && existing.trim() == picked) {
    return PageFontAction.noop;
  }
  return existing == null ? PageFontAction.add : PageFontAction.edit;
}
