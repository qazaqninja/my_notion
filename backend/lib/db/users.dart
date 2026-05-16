import 'package:postgres/postgres.dart';
import 'package:ulid/ulid.dart';

import '../auth/user.dart';

/// Data-layer repository for the `users` table. Wraps the raw Postgres
/// connection so callers (auth route handlers, session middleware) don't
/// hand-craft SQL.
///
/// All methods are async since `postgres` is fully async; lookups by id /
/// email use parameterised queries so the helpers can't be SQL-injected
/// even if a route handler passes untrusted user input directly.
class UserRepository {
  const UserRepository(this._conn);

  final Connection _conn;

  /// Insert a new user. Returns the persisted User on success.
  /// Throws `PgException` (or subclass) on constraint violations — the
  /// caller surface (POST /auth/signup) maps the uniqueness violation on
  /// `email` to a 409 response.
  Future<User> create({
    required String email,
    required String passwordHash,
  }) async {
    final id = Ulid().toString();
    final result = await _conn.execute(
      Sql.named('''
        INSERT INTO users (id, email, password_hash)
        VALUES (@id, @email, @hash)
        RETURNING id, email, created_at
      '''),
      parameters: {
        'id': id,
        'email': email,
        'hash': passwordHash,
      },
    );
    return _toUser(result.first);
  }

  /// Find a user by ULID. Returns null when not found.
  Future<User?> findById(String id) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT id, email, created_at FROM users WHERE id = @id LIMIT 1',
      ),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _toUser(result.first);
  }

  /// Find a user by email (case-sensitive — callers should lowercase first
  /// if a case-insensitive lookup is wanted; the auth route does).
  /// Returns null when not found.
  Future<User?> findByEmail(String email) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT id, email, created_at FROM users WHERE email = @email LIMIT 1',
      ),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    return _toUser(result.first);
  }

  /// Fetch the bcrypt `password_hash` column for [email] — used at login.
  /// Returns null when the user doesn't exist. The hash leaves the DB
  /// only in this one place; never in `findBy*` results.
  Future<String?> passwordHashOf(String email) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT password_hash FROM users WHERE email = @email LIMIT 1',
      ),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    return result.first[0] as String;
  }

  User _toUser(ResultRow row) => User(
        id: row[0] as String,
        email: row[1] as String,
        createdAt: row[2] as DateTime,
      );
}
