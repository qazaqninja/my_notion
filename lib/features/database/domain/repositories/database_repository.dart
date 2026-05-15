import 'dart:io' as io;

import '../entities/database_schema.dart';

class DatabasePageRow {
  const DatabasePageRow({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.cells,
    this.mtimeMs = 0,
    this.createdAt,
  });

  final String ulid;
  final String title;
  final String relativePath;

  /// frontmatter values keyed by column key, in raw form.
  final Map<String, dynamic> cells;

  /// File modification time in millis-since-epoch — drives the
  /// `last_edited_time` column type.
  final int mtimeMs;

  /// Optional explicit creation timestamp, sourced from the page's
  /// frontmatter `created_at:` field when present. Drives the
  /// `created_time` column type; when null, the cell renderer falls back
  /// to [mtimeMs].
  final String? createdAt;

  DatabasePageRow copyWith({
    Map<String, dynamic>? cells,
    String? title,
    int? mtimeMs,
    String? createdAt,
  }) {
    return DatabasePageRow(
      ulid: ulid,
      title: title ?? this.title,
      relativePath: relativePath,
      cells: cells ?? this.cells,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      createdAt: createdAt ?? this.createdAt,
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

  /// Import a CSV file as a new database folder under [vaultRoot]. The
  /// folder name comes from [folderName] or the CSV basename. Returns a
  /// summary of what landed; the indexer must be re-run after to pick
  /// up the new pages.
  Future<CsvImportResult> importCsv({
    required io.File source,
    required io.Directory vaultRoot,
    String? folderName,
  });

  /// Export [rows] of [schema] as a CSV file at [destination]. Returns
  /// the number of rows written.
  Future<int> exportCsv({
    required io.File destination,
    required DatabaseSchema schema,
    required List<DatabasePageRow> rows,
  });
}

/// Outcome of [DatabaseRepository.importCsv]. Exposed at the domain
/// layer so presentation code never imports data datasources directly
/// (CA-04 in docs/RULES.md).
class CsvImportResult {
  const CsvImportResult({
    required this.folderPath,
    required this.rowsWritten,
    required this.columns,
  });
  final String folderPath;
  final int rowsWritten;
  final int columns;
}

/// Thrown when a write operation hits a page whose frontmatter marks it
/// `locked: true` or `permissions: read_only`. The EditorBloc silently
/// drops mutations on locked pages (editor_bloc.dart:261); the
/// database repo throws this so the UI can show a specific error
/// rather than a generic 'Cell update failed'.
class PageLockedException implements Exception {
  const PageLockedException();
  @override
  String toString() => 'PageLockedException: page is locked or read-only';
}
