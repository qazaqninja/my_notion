import 'repositories/database_repository.dart';

/// Prepend the row's `icon:` cell to the title when it's a plain emoji
/// glyph. Returns the bare title otherwise.
///
/// Used by every "list of pages" surface in the database views (board,
/// timeline, calendar) so the rendering stays in sync across them.
/// Mirrors the gating in M253–M257: paths / URLs return the unchanged
/// title because we can't async-load an image into a 12–22px row.
String displayTitle(DatabasePageRow row) {
  final raw = '${row.cells['icon'] ?? ''}'.trim();
  if (raw.isEmpty || raw.length > 4 || raw.contains('/')) return row.title;
  return '$raw  ${row.title}';
}
