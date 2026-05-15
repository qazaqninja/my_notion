import 'repositories/database_repository.dart';

/// Plain-emoji `icon:` cell value for [row], or `null` when no plain
/// emoji is present (empty, asset paths, URLs, overly-long values).
/// Used by every view that has its own dedicated icon slot (gallery /
/// list / table) so the gating stays consistent across them.
String? rowIconString(DatabasePageRow row) {
  final raw = '${row.cells['icon'] ?? ''}'.trim();
  if (raw.isEmpty || raw.length > 4 || raw.contains('/')) return null;
  return raw;
}

/// Prepend the row's `icon:` cell to the title when it's a plain emoji
/// glyph. Returns the bare title otherwise. Empty titles fall back to
/// "Untitled" so empty rows stay visually distinct across board /
/// timeline / calendar — matches FCT (M621) and gallery/list (M622).
///
/// Used by every "list of pages" surface in the database views (board,
/// timeline, calendar) so the rendering stays in sync across them.
/// Mirrors the gating in M253–M257: paths / URLs return the unchanged
/// title because we can't async-load an image into a 12–22px row.
String displayTitle(DatabasePageRow row) {
  final emoji = rowIconString(row);
  final title = row.title.isEmpty ? 'Untitled' : row.title;
  return emoji == null ? title : '$emoji  $title';
}
