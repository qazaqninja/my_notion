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
  _Migration(2, '''
    -- E8 (M1300): sync layer's canonical vault file store.
    -- Composite PK (user_id, relpath) — one row per file in the user's
    -- mirrored vault. `sha256` lets clients compute deltas without
    -- transferring the full body. `mtime` is server-side write time.
    CREATE TABLE vault_files (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      relpath TEXT NOT NULL,
      sha256  TEXT NOT NULL,
      body    TEXT NOT NULL,
      mtime   TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, relpath)
    );
    CREATE INDEX idx_vault_files_user_mtime ON vault_files(user_id, mtime DESC);
  '''),
  _Migration(3, '''
    -- E16 (M1316): public sharing surface.
    -- `ulid` is the page identifier extracted from frontmatter `id:` —
    -- used by `GET /public/<ulid>` for cross-user lookup.
    -- `is_public` is extracted from frontmatter `public: true`; only
    -- pages with this set respond to the public route.
    ALTER TABLE vault_files ADD COLUMN ulid TEXT;
    ALTER TABLE vault_files ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT false;
    CREATE INDEX idx_vault_files_ulid_public
      ON vault_files(ulid) WHERE is_public = true;
  '''),
  _Migration(4, '''
    -- E43 (M1346): per-page password protection.
    -- `public_password_hash` holds a bcrypt hash extracted from the
    -- frontmatter `public_password:` field by FrontmatterProbe. When
    -- non-null the public route refuses to serve the rendered HTML
    -- until the visitor presents a valid unlock cookie.
    ALTER TABLE vault_files ADD COLUMN public_password_hash TEXT;
  '''),
];
