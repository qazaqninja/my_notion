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
}

abstract class DatabaseRepository {
  Future<List<DatabaseSchema>> listDatabases();
  Future<DatabaseSchema?> getDatabase(String id);
  Future<List<DatabasePageRow>> getRows(String databaseId);
}
