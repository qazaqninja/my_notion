import 'package:postgres/postgres.dart';

import '../sync/file_summary.dart';

/// Abstract data layer for the `vault_files` table. Sync routes accept
/// this interface so tests can plug in `_FakeSync` without a real
/// connection (same pattern as `UserRepositoryBase`).
abstract class SyncRepositoryBase {
  Future<List<FileSummary>> listFor(String userId);
}

class SyncRepository implements SyncRepositoryBase {
  const SyncRepository(this._conn);
  final Connection _conn;

  @override
  Future<List<FileSummary>> listFor(String userId) async {
    final rows = await _conn.execute(
      Sql.named('''
        SELECT relpath, sha256, mtime
        FROM vault_files
        WHERE user_id = @uid
        ORDER BY relpath ASC
      '''),
      parameters: {'uid': userId},
    );
    return [
      for (final row in rows)
        FileSummary(
          relpath: row[0] as String,
          sha256: row[1] as String,
          mtime: row[2] as DateTime,
        ),
    ];
  }
}
