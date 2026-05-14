import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/quill_database.dart' hide Page;
import '../domain/repositories/relations_repository.dart';

class RelationsRepositoryImpl implements RelationsRepository {
  RelationsRepositoryImpl(this._db);
  final QuillDatabase _db;

  @override
  Future<String?> resolveTitle(String ulid) async {
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(ulid)))
        .getSingleOrNull();
    return row?.title;
  }

  @override
  Future<List<Backlink>> backlinksFor(String toUlid) async {
    // Group by source page, take the earliest position per source.
    final query = _db.select(_db.pages).join([
      innerJoin(
        _db.relations,
        _db.relations.fromUlid.equalsExp(_db.pages.ulid),
      ),
    ])
      ..where(_db.relations.toUlid.equals(toUlid))
      ..orderBy([OrderingTerm(expression: _db.relations.position)]);

    final rows = await query.get();

    // De-duplicate per source page (a body can link to the same target many times).
    final seen = <String>{};
    final result = <Backlink>[];
    for (final r in rows) {
      final page = r.readTable(_db.pages);
      final rel = r.readTable(_db.relations);
      if (seen.contains(page.ulid)) continue;
      seen.add(page.ulid);
      result.add(
        Backlink(
          fromUlid: page.ulid,
          title: page.title,
          relativePath: page.relativePath,
          snippet: _snippetAround(page.bodyText, rel.position),
          emojiIcon: _emojiFromFrontmatter(page.frontmatterJson),
        ),
      );
    }
    return result;
  }

  static String? _emojiFromFrontmatter(String json) {
    if (json.isEmpty) return null;
    try {
      final m = jsonDecode(json);
      if (m is Map && m['icon'] is String) {
        final s = (m['icon'] as String).trim();
        if (s.isEmpty || s.contains('/') || s.startsWith('http')) return null;
        return s;
      }
    } catch (_) {/* ignore */}
    return null;
  }

  static String _snippetAround(String body, int linkPos, {int radius = 60}) {
    if (body.isEmpty) return '';
    final start = (linkPos - radius).clamp(0, body.length);
    final end = (linkPos + 30 + radius).clamp(0, body.length);
    var snippet = body.substring(start, end).replaceAll('\n', ' ').trim();
    if (start > 0) snippet = '…$snippet';
    if (end < body.length) snippet = '$snippet…';
    return snippet;
  }
}
