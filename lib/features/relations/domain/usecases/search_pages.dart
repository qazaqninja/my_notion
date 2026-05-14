import 'package:drift/drift.dart';

import '../../../../core/db/quill_database.dart' hide Page;

class PageSearchResult {
  const PageSearchResult({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.snippet,
  });
  final String ulid;
  final String title;
  final String relativePath;
  final String snippet;
}

/// FTS5-backed search across all indexed pages. When [query] is empty,
/// returns the most-recent N pages.
class SearchPages {
  const SearchPages(this._db);
  final QuillDatabase _db;

  Future<List<PageSearchResult>> call(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final rows = await (_db.select(_db.pages)
            ..orderBy([(p) => OrderingTerm(expression: p.mtimeMs, mode: OrderingMode.desc)])
            ..limit(limit))
          .get();
      return [
        for (final r in rows)
          PageSearchResult(
            ulid: r.ulid,
            title: r.title,
            relativePath: r.relativePath,
            snippet: _firstLine(r.bodyText),
          ),
      ];
    }

    // FTS5 MATCH with prefix wildcard. Escape double-quotes; the SQL
    // builder otherwise takes care of binding the string safely.
    final sanitized = trimmed.replaceAll('"', '""');
    final fts = '"$sanitized"*';
    final result = await _db
        .customSelect(
          '''
          SELECT pages.* FROM pages
          INNER JOIN pages_fts ON pages_fts.rowid = pages.rowid
          WHERE pages_fts MATCH ?
          ORDER BY rank
          LIMIT ?
          ''',
          variables: [Variable.withString(fts), Variable.withInt(limit)],
          readsFrom: {_db.pages},
        )
        .get();

    return [
      for (final r in result)
        PageSearchResult(
          ulid: r.read<String>('ulid'),
          title: r.read<String>('title'),
          relativePath: r.read<String>('relative_path'),
          snippet: _firstLine(r.read<String>('body_text')),
        ),
    ];
  }

  static String _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    final nl = trimmed.indexOf('\n');
    final line = nl == -1 ? trimmed : trimmed.substring(0, nl);
    return line.length > 80 ? '${line.substring(0, 80)}…' : line;
  }
}
