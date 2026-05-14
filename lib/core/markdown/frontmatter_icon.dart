import 'dart:convert';

/// Extract a plain-emoji `icon:` value from a page's cached
/// `frontmatter_json` (drift's `pages.frontmatter_json` column).
///
/// Asset paths and URLs are returned as `null` so callers fall back to
/// their default glyph — a 12–22px row can't render an async image
/// load. Empty / malformed JSON also returns `null`.
///
/// This is the single source of truth for the "page icon" gating used
/// across the sidebar tree, favorites + recent lists, command palette
/// page rows, backlinks rail, and standalone sub-page cards (M253–M257).
String? emojiFromFrontmatterJson(String json) {
  if (json.isEmpty) return null;
  try {
    final m = jsonDecode(json);
    if (m is Map && m['icon'] is String) {
      final s = (m['icon'] as String).trim();
      if (s.isEmpty || s.contains('/') || s.startsWith('http')) return null;
      return s;
    }
  } catch (_) {/* malformed cached frontmatter — fall through */}
  return null;
}
