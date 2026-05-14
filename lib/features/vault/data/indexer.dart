import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';

// Drift's `Page` data class from the `pages` table conflicts with our
// domain entity — hide it.
import '../../../core/db/quill_database.dart' hide Page;
import '../../../core/markdown/wikilink_parser.dart';
import '../domain/entities/page.dart';
import 'datasources/vault_fs_datasource.dart';

/// Rebuilds the Drift cache from disk. The brief's day-one contract:
/// nuke the SQLite file → re-run [reindex] → app state byte-identical.
class Indexer {
  Indexer(this._db, this._ds);

  final QuillDatabase _db;
  final VaultFsDatasource _ds;

  Future<void> reindex(io.Directory root) async {
    await _db.transaction(() async {
      await _db.delete(_db.pages).go();
      await _db.delete(_db.relations).go();
      await _db.delete(_db.databases).go();

      // We re-use the package:file abstraction via _ds.fs. The caller passes
      // a dart:io Directory; resolve to the equivalent file-package Directory.
      final dir = _ds.fs.directory(root.path);
      await for (final page in _ds.scan(dir)) {
        await _upsertPage(page);
        await _insertRelationsFor(page);
      }
    });
  }

  /// Single-page update — used after editor saves (M5) to avoid full reindex.
  Future<void> upsertPage(Page page) async {
    await _db.transaction(() async {
      await _upsertPage(page);
      // Replace this page's outgoing relations.
      await (_db.delete(_db.relations)..where((r) => r.fromUlid.equals(page.ulid))).go();
      await _insertRelationsFor(page);
    });
  }

  Future<void> _upsertPage(Page page) async {
    final fmJson = jsonEncode({
      'entries': page.frontmatter.entries
          .map((e) => {
                'key': e.key,
                'rawScalar': e.rawScalar,
                'type': e.type.name,
              })
          .toList(),
    });
    await _db.into(_db.pages).insertOnConflictUpdate(PagesCompanion.insert(
          ulid: page.ulid,
          relativePath: page.relativePath,
          title: page.title,
          frontmatterJson: fmJson,
          bodyText: page.body,
          mtimeMs: Value(page.mtimeMs),
          databaseId: const Value(null),
        ));
  }

  Future<void> _insertRelationsFor(Page page) async {
    for (final link in WikilinkParser.find(page.body)) {
      await _db.into(_db.relations).insertOnConflictUpdate(RelationsCompanion.insert(
            fromUlid: page.ulid,
            toUlid: link.ulid,
            position: link.start,
          ));
    }
  }
}
