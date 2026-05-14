import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../datasources/database_yaml_parser.dart';

class DatabaseRepositoryImpl implements DatabaseRepository {
  DatabaseRepositoryImpl(this._db);
  final QuillDatabase _db;

  @override
  Future<List<DatabaseSchema>> listDatabases() async {
    final rows = await _db.select(_db.databases).get();
    final schemas = <DatabaseSchema>[];
    for (final r in rows) {
      final s = DatabaseYamlParser.parse(r.schemaYaml, folderPath: r.folderPath);
      if (s != null) schemas.add(s);
    }
    return schemas;
  }

  @override
  Future<DatabaseSchema?> getDatabase(String id) async {
    final row = await (_db.select(_db.databases)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return DatabaseYamlParser.parse(row.schemaYaml, folderPath: row.folderPath);
  }

  @override
  Future<List<DatabasePageRow>> getRows(String databaseId) async {
    final rows = await (_db.select(_db.pages)
          ..where((p) => p.databaseId.equals(databaseId))
          ..orderBy([(p) => OrderingTerm.asc(p.title)]))
        .get();
    return [
      for (final row in rows)
        DatabasePageRow(
          ulid: row.ulid,
          title: row.title,
          relativePath: row.relativePath,
          cells: _decodeCells(row.frontmatterJson),
        ),
    ];
  }

  Map<String, dynamic> _decodeCells(String fmJson) {
    if (fmJson.isEmpty) return const {};
    try {
      final decoded = jsonDecode(fmJson);
      if (decoded is! Map<String, dynamic>) return const {};
      final entries = decoded['entries'];
      if (entries is! List) return const {};
      final out = <String, dynamic>{};
      for (final e in entries) {
        if (e is Map<String, dynamic>) {
          final key = e['key']?.toString();
          final raw = e['rawScalar']?.toString();
          if (key != null) out[key] = raw ?? '';
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}

