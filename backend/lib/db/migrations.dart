import 'package:postgres/postgres.dart';

/// Inline migration runner — minimal but durable.
///
/// On boot, ensures a `schema_migrations(version)` table exists and applies
/// any migrations not yet recorded. Each migration is a self-contained SQL
/// string with an integer `version` so the ordering is unambiguous.
///
/// Adding a new migration: bump the highest version, prepend the new SQL,
/// append the version to the `_migrations` list. Migrations are
/// **immutable once shipped** — write a follow-up migration to alter an
/// earlier one rather than editing it in place.
Future<void> runMigrations(Connection conn) async {
  await conn.execute('''
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  ''');

  final applied = (await conn.execute('SELECT version FROM schema_migrations'))
      .map((row) => row[0] as int)
      .toSet();

  for (final m in _migrations) {
    if (applied.contains(m.version)) continue;
    await conn.runTx<void>((tx) async {
      await tx.execute(m.sql);
      await tx.execute(
        Sql.named('INSERT INTO schema_migrations(version) VALUES (@v)'),
        parameters: {'v': m.version},
      );
    });
  }
}

class _Migration {
  const _Migration(this.version, this.sql);
  final int version;
  final String sql;
}

/// Migration registry — append-only. Bump version, write SQL, ship.
const _migrations = <_Migration>[
  _Migration(1, '''
    -- E2 (M1288): initial schema.
    -- Just `users` for now; sync / vault tables land in later slices.
    CREATE TABLE users (
      id TEXT PRIMARY KEY,                -- ULID
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  '''),
];
