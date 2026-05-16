import 'package:postgres/postgres.dart';

import '../sync/file_summary.dart';
import '../sync/frontmatter_probe.dart';

/// Result of `upsert` — either the new persisted summary, or a
/// conflict-with-the-current-server-state when `ifMatch` didn't match.
class UpsertOutcome {
  const UpsertOutcome.persisted(this.summary) : conflict = null;
  const UpsertOutcome.conflict(this.conflict) : summary = null;

  /// Persisted summary on success, null on conflict.
  final FileSummary? summary;

  /// The server's current FileSummary on conflict — clients should
  /// reconcile by fetching this version. null on success.
  final FileSummary? conflict;

  bool get isConflict => conflict != null;
}

/// Abstract data layer for the `vault_files` table. Sync routes accept
/// this interface so tests can plug in `_FakeSync` without a real
/// connection (same pattern as `UserRepositoryBase`).
abstract class SyncRepositoryBase {
  Future<List<FileSummary>> listFor(String userId);

  /// Upsert one file with optional optimistic-concurrency preflight via
  /// [ifMatch]:
  ///
  /// - If [ifMatch] is null, the write is unconditional.
  /// - If [ifMatch] is `"*"`, the write succeeds only when no row
  ///   currently exists.
  /// - Otherwise the write succeeds only when the current row's sha256
  ///   equals [ifMatch] OR there is no current row (treat-as-create).
  ///
  /// On conflict the returned outcome carries the server's current
  /// summary so clients can reconcile.
  Future<UpsertOutcome> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
    String? ifMatch,
  });

  /// Fetch the full file payload (summary + body). Returns null when no
  /// row exists for (userId, relpath). Scoped to the caller's user_id —
  /// the route layer's `currentUser(req).id` is the only valid argument.
  Future<FileBody?> fetch({
    required String userId,
    required String relpath,
  });

  /// Delete one file. Returns true iff a row was actually removed.
  Future<bool> delete({
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
  Future<UpsertOutcome> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
    String? ifMatch,
  }) async {
    return _conn.runTx<UpsertOutcome>((tx) async {
      FileSummary? current;
      if (ifMatch != null) {
        final preflight = await tx.execute(
          Sql.named('''
            SELECT relpath, sha256, mtime FROM vault_files
            WHERE user_id = @uid AND relpath = @rel
            LIMIT 1
          '''),
          parameters: {'uid': userId, 'rel': relpath},
        );
        if (preflight.isNotEmpty) {
          final row = preflight.first;
          current = FileSummary(
            relpath: row[0] as String,
            sha256: row[1] as String,
            mtime: row[2] as DateTime,
          );
        }
        if (ifMatch == '*') {
          if (current != null) {
            return UpsertOutcome.conflict(current);
          }
        } else {
          // Conflict if a row exists with a different sha256. No row →
          // treat-as-create (caller's expected sha256 doesn't matter,
          // since they're not racing against a known version).
          if (current != null && current.sha256 != ifMatch) {
            return UpsertOutcome.conflict(current);
          }
        }
      }
      final probe = FrontmatterProbe.fromBody(body);
      final rows = await tx.execute(
        Sql.named('''
          INSERT INTO vault_files
            (user_id, relpath, sha256, body, mtime, ulid, is_public)
          VALUES (@uid, @rel, @sha, @body, now(), @ulid, @public)
          ON CONFLICT (user_id, relpath) DO UPDATE
            SET sha256    = EXCLUDED.sha256,
                body      = EXCLUDED.body,
                mtime     = now(),
                ulid      = EXCLUDED.ulid,
                is_public = EXCLUDED.is_public
          RETURNING relpath, sha256, mtime
        '''),
        parameters: {
          'uid': userId,
          'rel': relpath,
          'sha': sha256,
          'body': body,
          'ulid': probe.ulid,
          'public': probe.isPublic,
        },
      );
      final row = rows.first;
      return UpsertOutcome.persisted(
        FileSummary(
          relpath: row[0] as String,
          sha256: row[1] as String,
          mtime: row[2] as DateTime,
        ),
      );
    });
  }

  @override
  Future<bool> delete({
    required String userId,
    required String relpath,
  }) async {
    final result = await _conn.execute(
      Sql.named('''
        DELETE FROM vault_files
        WHERE user_id = @uid AND relpath = @rel
      '''),
      parameters: {'uid': userId, 'rel': relpath},
    );
    return result.affectedRows > 0;
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
