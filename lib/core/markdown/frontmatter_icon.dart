import 'dart:convert';

/// Returns the rawScalar of the frontmatter entry with [key] from the
/// drift-cached JSON blob written by Indexer._upsertPage. The blob's
/// shape is `{entries: [{key, rawScalar, type}, …]}` — a nested
/// structure that callers used to walk with `m[key]` (which silently
/// resolved to null and silently broke icon display, title detection,
/// reminder surfacing, and tag filtering across the app).
///
/// Returns null when the JSON is malformed, the key is absent, or the
/// entry's rawScalar is non-string.
String? rawScalarFromFrontmatterJson(String json, String key) {
  if (json.isEmpty) return null;
  try {
    final m = jsonDecode(json);
    if (m is! Map) return null;
    final entries = m['entries'];
    if (entries is! List) return null;
    for (final e in entries) {
      if (e is Map && e['key'] == key) {
        final raw = e['rawScalar'];
        if (raw is String) return raw;
        return null;
      }
    }
  } catch (_) {/* malformed cached frontmatter — fall through */}
  return null;
}

/// Strip a single layer of YAML double- or single-quotes around [s].
/// Idempotent on unquoted scalars.
String _unquoteYaml(String s) {
  if (s.length < 2) return s;
  if ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'"))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

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
  final raw = rawScalarFromFrontmatterJson(json, 'icon');
  if (raw == null) return null;
  final s = _unquoteYaml(raw).trim();
  if (s.isEmpty || s.contains('/') || s.startsWith('http')) return null;
  return s;
}

/// Parse a YAML flow list rawScalar (e.g. `[draft, "urgent, now"]`) into
/// its constituent strings. Bare single values are wrapped in a
/// one-element list so the caller can treat both shapes uniformly.
List<String> _parseFlowList(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
    final s = _unquoteYaml(trimmed);
    return s.isEmpty ? const [] : [s];
  }
  final inner = trimmed.substring(1, trimmed.length - 1);
  if (inner.trim().isEmpty) return const [];
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  String? quoteChar;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (inQuotes) {
      if (ch == quoteChar) {
        inQuotes = false;
        quoteChar = null;
      } else {
        buf.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      inQuotes = true;
      quoteChar = ch;
    } else if (ch == ',') {
      final v = buf.toString().trim();
      if (v.isNotEmpty) out.add(_unquoteYaml(v));
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add(_unquoteYaml(tail));
  return out;
}

/// Returns the list-of-strings stored under [key] in the cached
/// frontmatter JSON. Handles flow lists (`[a, b]`), single scalar
/// values (`a` → `['a']`), and missing / malformed entries (`[]`).
///
/// Used by tag aggregation surfaces (Tags page, command palette
/// `tag:` filter, vault stats), all of which previously looked up
/// `m['tags']` on the nested cache shape and silently got null.
List<String> listValueFromFrontmatterJson(String json, String key) {
  final raw = rawScalarFromFrontmatterJson(json, key);
  if (raw == null) return const [];
  return _parseFlowList(raw);
}

/// True when the entry exists AND its rawScalar trims to non-empty.
/// Used by the "pages without a title" hygiene check.
bool hasNonEmptyFrontmatterValue(String json, String key) {
  final raw = rawScalarFromFrontmatterJson(json, key);
  if (raw == null) return false;
  return _unquoteYaml(raw).trim().isNotEmpty;
}
