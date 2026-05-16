import 'package:postgres/postgres.dart';

import '../sync/file_summary.dart';

/// Abstract data layer for the `vault_files` table. Sync routes accept
/// this interface so tests can plug in `_FakeSync` without a real
/// connection (same pattern as `UserRepositoryBase`).
abstract class SyncRepositoryBase {
  Future<List<FileSummary>> listFor(String userId);

  /// Upsert one file. The new server-side `mtime` is recorded on every
  /// write so clients can sort by recent activity. Returns the
  /// canonical `FileSummary` from the persisted row.
  Future<FileSummary> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
  });

  /// Fetch the full file payload (summary + body). Returns null when no
  /// row exists for (userId, relpath). Scoped to the caller's user_id —
  /// the route layer's `currentUser(req).id` is the only valid argument.
  Future<FileBody?> fetch({
    required String userId,
    required String relpath,
  });
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

  @override
  Future<FileSummary> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
  }) async {
    final rows = await _conn.execute(
      Sql.named('''
        INSERT INTO vault_files (user_id, relpath, sha256, body, mtime)
        VALUES (@uid, @rel, @sha, @body, now())
        ON CONFLICT (user_id, relpath) DO UPDATE
          SET sha256 = EXCLUDED.sha256,
              body   = EXCLUDED.body,
              mtime  = now()
        RETURNING relpath, sha256, mtime
      '''),
      parameters: {
        'uid': userId,
        'rel': relpath,
        'sha': sha256,
        'body': body,
      },
    );
    final row = rows.first;
    return FileSummary(
      relpath: row[0] as String,
      sha256: row[1] as String,
      mtime: row[2] as DateTime,
    );
  }

  @override
  Future<FileBody?> fetch({
    required String userId,
    required String relpath,
  }) async {
    final rows = await _conn.execute(
      Sql.named('''
        SELECT relpath, sha256, mtime, body
        FROM vault_files
        WHERE user_id = @uid AND relpath = @rel
        LIMIT 1
      '''),
      parameters: {'uid': userId, 'rel': relpath},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return FileBody(
      summary: FileSummary(
        relpath: row[0] as String,
        sha256: row[1] as String,
        mtime: row[2] as DateTime,
      ),
      body: row[3] as String,
    );
  }
}
