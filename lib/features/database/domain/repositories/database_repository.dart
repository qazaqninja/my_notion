import 'dart:io' as io;

import '../entities/database_schema.dart';

class DatabasePageRow {
  const DatabasePageRow({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.cells,
  });

  final String ulid;
  final String title;
  final String relativePath;

  /// frontmatter values keyed by column key, in raw form.
  final Map<String, dynamic> cells;

  DatabasePageRow copyWith({Map<String, dynamic>? cells, String? title}) {
    return DatabasePageRow(
      ulid: ulid,
      title: title ?? this.title,
      relativePath: relativePath,
      cells: cells ?? this.cells,
    );
  }
}

abstract class DatabaseRepository {
  Future<List<DatabaseSchema>> listDatabases();
  Future<DatabaseSchema?> getDatabase(String id);
  Future<List<DatabasePageRow>> getRows(String databaseId);

  /// Write a single cell back to disk. Mutates the page's frontmatter entry
  /// for [columnKey] (creating it if absent), writes the .md, and updates
  /// the Drift cache. Returns the updated row.
  Future<DatabasePageRow> updateCell({
    required String ulid,
    required ColumnDef column,
    required Object? newValue,
    required io.Directory vaultRoot,
  });

  /// Create a new .md page inside the database's folder, write it, and
  /// upsert it into Drift. Returns the new row.
  Future<DatabasePageRow> createRow({
    required DatabaseSchema schema,
    required String title,
    required io.Directory vaultRoot,
  });
}
