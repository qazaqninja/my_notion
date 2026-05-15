/// Roam Research JSON export → CommonMark converter.
///
/// Roam exports a top-level JSON array of pages. Each page is a map
/// with `title`, optional `create-time` (millis), and a `children`
/// array of blocks. Each block has a `string` (the bullet text) and
/// its own `children`. Pages can include `[[Page Name]]` references —
/// we leave them as-is since the user can resolve them after import
/// by creating the linked pages or doing a search/replace.
///
/// Output: one bullet list per page, nested two spaces per child
/// level. The first line of the page is the title as an H1 so the
/// page renders sensibly even outside Roam's "every line is a bullet"
/// convention.
library;

import 'dart:convert';

class RoamPage {
  const RoamPage({
    required this.title,
    required this.body,
    this.createdAtMs,
  });
  final String title;
  final String body;

  /// `create-time` from the Roam export, when present. Surfaced as a
  /// `created_at:` frontmatter entry by the importer.
  final int? createdAtMs;
}

class RoamToMarkdown {
  const RoamToMarkdown._();

  /// Parse a Roam JSON export string and return one [RoamPage] per
  /// top-level entry. Malformed JSON returns an empty list — caller
  /// surfaces "no pages found" rather than crashing.
  static List<RoamPage> convert(String json) {
    final dynamic doc;
    try {
      doc = jsonDecode(json);
    } catch (_) {
      return const [];
    }
    if (doc is! List) return const [];
    final out = <RoamPage>[];
    for (final entry in doc) {
      if (entry is! Map) continue;
      final title = '${entry['title'] ?? ''}'.trim();
      if (title.isEmpty) continue;
      final childrenRaw = entry['children'];
      final lines = <String>[];
      lines.add('# $title');
      lines.add('');
      if (childrenRaw is List) {
        _walk(childrenRaw, 0, lines);
      }
      final createdAt = entry['create-time'];
      out.add(RoamPage(
        title: title,
        body: lines.join('\n'),
        createdAtMs: createdAt is int ? createdAt : null,
      ));
    }
    return out;
  }

  static void _walk(List<dynamic> children, int depth, List<String> out) {
    for (final node in children) {
      if (node is! Map) continue;
      final s = '${node['string'] ?? ''}';
      // Skip empty bullets — Roam uses them to space things visually
      // but they produce ugly `-  ` lines on import.
      if (s.trim().isNotEmpty) {
        out.add('${'  ' * depth}- $s');
      }
      final kids = node['children'];
      if (kids is List) _walk(kids, depth + 1, out);
    }
  }
}
