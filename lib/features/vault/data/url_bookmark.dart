import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/ulid/ulid_generator.dart';

/// Capture a URL as a new page under `<vault>/Bookmarks/<host>-<slug>.md`.
/// Body is a single standalone URL on its own line, which the
/// MarkdownRenderer picks up as a `_BookmarkCard` (M42). Frontmatter
/// carries id / title (host + path) / url / created_at.
class UrlBookmark {
  const UrlBookmark._();

  static const _ulids = UlidGenerator();

  static Future<UrlBookmarkResult> capture(
    String url,
    Directory vaultRoot,
  ) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty url');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.host.isEmpty) {
      throw const FormatException('not a URL');
    }
    // Require http/https — other schemes (file://, mailto:, javascript:,
    // protocol-relative '//host', etc.) would either fail to render as
    // a bookmark card (markdown_renderer requires https?://) or be
    // outright dangerous to autolaunch.
    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const FormatException('only http and https URLs are supported');
    }
    final folder = Directory(p.join(vaultRoot.path, 'Bookmarks'));
    await folder.create(recursive: true);
    final ulid = _ulids.generate();
    final today =
        DateTime.now().toIso8601String().substring(0, 10);
    final host = parsed.host;
    final pathPart = parsed.path
        .replaceAll(RegExp(r'^/+|/+\$'), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final base = pathPart.isEmpty ? host : '$host-$pathPart';
    final title = base.length > 100 ? base.substring(0, 100) : base;
    final safe = _safeFileName(title);
    final rel = p.join('Bookmarks', '$safe.md');
    final file = File(p.join(vaultRoot.path, rel));
    final buf = StringBuffer('---\n')
      ..writeln('id: $ulid')
      ..writeln('title: ${yamlSafeScalar(title)}')
      ..writeln('url: ${yamlSafeScalar(trimmed)}')
      ..writeln('created_at: $today')
      ..writeln('tags: [bookmark]')
      ..writeln('---')
      ..writeln()
      ..writeln(trimmed)
      ..writeln();
    await file.writeAsString(buf.toString());
    return UrlBookmarkResult(ulid: ulid, relativePath: rel, title: title);
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Bookmark';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

}

class UrlBookmarkResult {
  const UrlBookmarkResult({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}
