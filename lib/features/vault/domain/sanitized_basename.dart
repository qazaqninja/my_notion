/// Sanitise a user-supplied page basename for use as the filename on
/// disk. Mirrors the legacy `_safeFileName` transformation used by
/// the editor's `_renameFile` handler:
///
/// - replace filesystem-illegal chars (`\\/<>:"|?*`) with `-`,
/// - collapse runs of whitespace,
/// - trim leading/trailing whitespace,
/// - strip a trailing `.md` (case-insensitive),
/// - fall back to `"Untitled"` if the result would be empty.
///
/// Centralised so the rename preview ("Renamed to X.md") matches what
/// `RenamePage` ultimately persists on disk — keeps the rename UX
/// honest without forcing every call site to repeat the logic.
String sanitizedBasename(String input) {
  var s = input
      .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.toLowerCase().endsWith('.md')) {
    s = s.substring(0, s.length - 3).trim();
  }
  if (s.isEmpty || s == '-' || s == '--' || s == '---') return 'Untitled';
  return s;
}
