import 'frontmatter.dart';

/// A single markdown page on disk. ULID is the stable identifier; the path
/// can change without breaking relations.
class Page {
  const Page({
    required this.ulid,
    required this.relativePath,
    required this.title,
    required this.frontmatter,
    required this.body,
    this.mtimeMs = 0,
  });

  /// Crockford base-32 ULID (26 chars).
  final String ulid;

  /// Path relative to vault root, e.g. `Operations/Customers/Northwind.md`.
  final String relativePath;

  /// Title — either `frontmatter['title']` or derived from the filename.
  final String title;

  final Frontmatter frontmatter;

  /// Markdown body after the closing `---` line (excluding the leading
  /// newline). Empty if the file has no frontmatter.
  final String body;

  /// File modification time in milliseconds since epoch.
  final int mtimeMs;

  Page copyWith({
    String? ulid,
    String? relativePath,
    String? title,
    Frontmatter? frontmatter,
    String? body,
    int? mtimeMs,
  }) {
    return Page(
      ulid: ulid ?? this.ulid,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      frontmatter: frontmatter ?? this.frontmatter,
      body: body ?? this.body,
      mtimeMs: mtimeMs ?? this.mtimeMs,
    );
  }

  @override
  String toString() => 'Page($ulid · $relativePath)';
}

/// A parsed markdown document — output of [FrontmatterParser.parse]. Distinct
/// from [Page] because parsing happens before we know the path / mtime / etc.
class ParsedMarkdown {
  const ParsedMarkdown({required this.frontmatter, required this.body});
  final Frontmatter frontmatter;
  final String body;
}
