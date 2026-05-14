import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

// Drift's `Page` data class from the `pages` table conflicts with our
// domain entity — hide it.
import '../../../core/db/quill_database.dart' hide Page;
import '../../../core/markdown/wikilink_parser.dart';
import '../../database/data/datasources/database_yaml_parser.dart';
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

      final dir = _ds.fs.directory(root.path);

      // Pass 1: discover databases — every `.database.yaml` file in the tree.
      final dbIdByFolderPath = <String, String>{};
      await for (final dbRow in _scanDatabases(dir, root.path)) {
        dbIdByFolderPath[dbRow.folderPath] = dbRow.id;
        await _db.into(_db.databases).insertOnConflictUpdate(
              DatabasesCompanion.insert(
                id: dbRow.id,
                name: dbRow.name,
                folderPath: dbRow.folderPath,
                schemaYaml: dbRow.schemaYaml,
              ),
            );
      }

      // Pass 2: index pages — tag each page with the closest enclosing
      // database folder (if any).
      await for (final page in _ds.scan(dir)) {
        final databaseId = _findEnclosingDb(page.relativePath, dbIdByFolderPath);
        await _upsertPage(page, databaseId: databaseId);
        await _insertRelationsFor(page);
      }
    });
  }

  Stream<_DatabaseRow> _scanDatabases(io.Directory root, String rootPath) async* {
    await for (final entity in _walkAll(root)) {
      if (entity is! io.File) continue;
      if (p.basename(entity.path) != '.database.yaml') continue;
      final yaml = await entity.readAsString();
      final folderAbs = p.dirname(entity.path);
      final folderRel = p.relative(folderAbs, from: rootPath);
      final schema = DatabaseYamlParser.parse(yaml, folderPath: folderRel);
      if (schema == null || schema.id.isEmpty) continue;
      yield _DatabaseRow(
        id: schema.id,
        name: schema.name,
        folderPath: folderRel,
        schemaYaml: yaml,
      );
    }
  }

  Stream<io.FileSystemEntity> _walkAll(io.Directory dir) async* {
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (entity is io.Directory) {
        if (const {'.git', '.obsidian', 'node_modules', '_meta', '.dart_tool', '.idea', '.trash'}
            .contains(name)) {
          continue;
        }
        yield* _walkAll(entity);
      } else {
        yield entity;
      }
    }
  }

  String? _findEnclosingDb(String relPath, Map<String, String> dbIdByFolderPath) {
    if (dbIdByFolderPath.isEmpty) return null;
    String? best;
    int bestLen = -1;
    final pageFolder = p.dirname(relPath);
    for (final entry in dbIdByFolderPath.entries) {
      final folder = entry.key;
      if (folder.isEmpty || folder == '.') continue;
      if (pageFolder == folder || pageFolder.startsWith('$folder${p.separator}')) {
        if (folder.length > bestLen) {
          bestLen = folder.length;
          best = entry.value;
        }
      }
    }
    return best;
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

  Future<void> _upsertPage(Page page, {String? databaseId}) async {
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
          databaseId: Value(databaseId),
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

class _DatabaseRow {
  const _DatabaseRow({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.schemaYaml,
  });
  final String id;
  final String name;
  final String folderPath;
  final String schemaYaml;
}
