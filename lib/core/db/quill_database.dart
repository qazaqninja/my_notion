import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'quill_database.g.dart';

/// One row per markdown page on disk. The Drift cache is a projection — disk
/// is the source of truth. Wiping this database and re-running [Indexer]
/// must produce identical state (see `test/integration/reindex_idempotent_test.dart`).
class Pages extends Table {
  TextColumn get ulid => text().withLength(min: 26, max: 26)();
  TextColumn get relativePath => text()();
  TextColumn get title => text()();
  TextColumn get frontmatterJson => text()();
  TextColumn get bodyText => text()();
  IntColumn get mtimeMs => integer().withDefault(const Constant(0))();
  TextColumn get databaseId => text().nullable()();

  @override
  Set<Column> get primaryKey => {ulid};
}

/// Wikilink edge — from one page's body to another page (by ULID). Multiple
/// occurrences of the same target in one body produce multiple rows
/// distinguished by [position].
class Relations extends Table {
  TextColumn get fromUlid => text()();
  TextColumn get toUlid => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {fromUlid, toUlid, position};
}

/// Database = folder + `.database.yaml`. Holds the parsed schema as raw YAML
/// for round-trip and the canonical name/path. Pages.databaseId references id.
class Databases extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get folderPath => text()();
  TextColumn get schemaYaml => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Pages, Relations, Databases])
class QuillDatabase extends _$QuillDatabase {
  QuillDatabase() : super(_open());

  /// Tests inject [NativeDatabase.memory()].
  QuillDatabase.forTesting(super.executor);

  static QueryExecutor _open() => driftDatabase(name: 'quill');

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX idx_pages_db ON pages(database_id);');
          await customStatement('CREATE INDEX idx_pages_path ON pages(relative_path);');
          await customStatement('CREATE INDEX idx_relations_to ON relations(to_ulid);');
          await customStatement('''
            CREATE VIRTUAL TABLE pages_fts USING fts5(
              title, body, content='pages', content_rowid='rowid'
            );
          ''');
          await customStatement('''
            CREATE TRIGGER pages_ai AFTER INSERT ON pages BEGIN
              INSERT INTO pages_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body_text);
            END;
          ''');
          await customStatement('''
            CREATE TRIGGER pages_ad AFTER DELETE ON pages BEGIN
              INSERT INTO pages_fts(pages_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body_text);
            END;
          ''');
          await customStatement('''
            CREATE TRIGGER pages_au AFTER UPDATE ON pages BEGIN
              INSERT INTO pages_fts(pages_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body_text);
              INSERT INTO pages_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body_text);
            END;
          ''');
        },
      );

  /// Stable, sorted dump of the cache used by the reindex-idempotency
  /// integration test. JSON-encode each table's contents with deterministic
  /// ordering so equality is byte-identical.
  Future<DatabaseSnapshot> snapshot() async {
    final pageRows = await (select(pages)..orderBy([(p) => OrderingTerm.asc(p.ulid)])).get();
    final relationRows = await (select(relations)
          ..orderBy([
            (r) => OrderingTerm.asc(r.fromUlid),
            (r) => OrderingTerm.asc(r.toUlid),
            (r) => OrderingTerm.asc(r.position),
          ]))
        .get();
    final dbRows = await (select(databases)..orderBy([(d) => OrderingTerm.asc(d.id)])).get();
    return DatabaseSnapshot(
      pages: pageRows
          .map((p) => {
                'ulid': p.ulid,
                'relativePath': p.relativePath,
                'title': p.title,
                'frontmatterJson': p.frontmatterJson,
                'bodyText': p.bodyText,
                'databaseId': p.databaseId,
                // mtime is intentionally excluded — it changes between runs
                // for the same files. Disk truth ≠ filesystem timestamps.
              })
          .toList(),
      relations: relationRows
          .map((r) => {
                'fromUlid': r.fromUlid,
                'toUlid': r.toUlid,
                'position': r.position,
              })
          .toList(),
      databases: dbRows
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'folderPath': d.folderPath,
                'schemaYaml': d.schemaYaml,
              })
          .toList(),
    );
  }
}

/// Stable, byte-comparable snapshot of cache state. Excludes mtime since it
/// changes between runs on the same files.
class DatabaseSnapshot {
  const DatabaseSnapshot({required this.pages, required this.relations, required this.databases});

  final List<Map<String, Object?>> pages;
  final List<Map<String, Object?>> relations;
  final List<Map<String, Object?>> databases;

  String encode() => jsonEncode({
        'pages': pages,
        'relations': relations,
        'databases': databases,
      });

  @override
  bool operator ==(Object other) => other is DatabaseSnapshot && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;

  @override
  String toString() => 'DatabaseSnapshot(pages=${pages.length}, relations=${relations.length}, databases=${databases.length})';
}
