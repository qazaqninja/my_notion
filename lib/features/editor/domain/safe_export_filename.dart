/// Reserved characters disallowed in cross-platform filenames —
/// matches the legacy `editor_page.dart` regex used by every export
/// handler (export-md / export-html). Centralised so a future tuning
/// (e.g. allow non-Latin scripts more aggressively) flips both
/// exporters at once.
final RegExp _reservedChars = RegExp(r'[\\/:*?"<>|]');

/// Returns a safe filename derived from [title]:
///   1. Substitute every char matching the legacy reserved set with
///      `_`.
///   2. Trim leading/trailing whitespace.
///   3. Fall back to [fallback] (`'page'` by default) when the result
///      is empty.
///
/// Pulled into the domain layer at M1747 so the D-fp22 export-md /
/// export-html handlers in [editor_beta_page.dart] (and any future
/// export flavour) share one byte-identical normaliser. The legacy
/// helper used `safeName.isEmpty ? 'page' : safeName` after the
/// trim — preserved exactly so existing exports collide with the
/// legacy flow on the same input.
String safeExportFilename(String title, {String fallback = 'page'}) {
  final cleaned = title.replaceAll(_reservedChars, '_').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}
