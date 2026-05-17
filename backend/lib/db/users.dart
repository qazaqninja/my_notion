import 'package:backend/auth/user.dart';
import 'package:backend/db/exceptions.dart';
import 'package:postgres/postgres.dart';
import 'package:ulid/ulid.dart';

/// Thrown by `UserRepository.create` when the unique constraint on
/// `users.email` is violated. The auth routes catch this and surface a
/// `409 email_taken` response.
///
/// Extends `DbException` (F7) so `runDb` passes it through untouched
/// instead of re-wrapping it as `DbUnavailableException`.
class EmailAlreadyTakenException extends DbException {
  const EmailAlreadyTakenException(this.email) : super('email_taken');
  final String email;
  @override
  String toString() => 'EmailAlreadyTakenException: $email';
}

/// Abstract base for the User data layer. Routes / services accept this
/// interface so tests can plug in a FakeUserRepository without
/// constructing a real postgres connection.
abstract class UserRepositoryBase {
  Future<User> create({required String email, required String passwordHash});
  Future<User?> findById(String id);
  Future<User?> findByEmail(String email);
  Future<String?> passwordHashOf(String email);
}

/// Postgres-backed implementation. Wraps the raw connection so callers
/// (auth route handlers, session middleware) don't hand-craft SQL.
class UserRepository implements UserRepositoryBase {
  const UserRepository(this._conn);

  final Connection _conn;

  @override
  Future<User> create({
    required String email,
    required String passwordHash,
  }) async =>
      runDb(op: 'users.create', () async {
        final id = Ulid().toString();
        try {
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
        } on PgException catch (e) {
          // Postgres SQLSTATE 23505 = unique_violation. Translate to
          // the typed exception so callers don't depend on the
          // postgres package. EmailAlreadyTakenException is itself a
          // DbException subtype, so runDb passes it through unchanged.
          final msg = e.toString();
          if (msg.contains('23505') || msg.contains('users_email_key')) {
            throw EmailAlreadyTakenException(email);
          }
          rethrow;
        }
      });

  @override
  Future<User?> findById(String id) async =>
      runDb(op: 'users.findById', () async {
        final result = await _conn.execute(
          Sql.named(
            'SELECT id, email, created_at FROM users WHERE id = @id LIMIT 1',
          ),
          parameters: {'id': id},
        );
        if (result.isEmpty) return null;
        return _toUser(result.first);
      });

  @override
  Future<User?> findByEmail(String email) async =>
      runDb(op: 'users.findByEmail', () async {
        final result = await _conn.execute(
          Sql.named(
            'SELECT id, email, created_at FROM users '
            'WHERE email = @email LIMIT 1',
          ),
          parameters: {'email': email},
        );
        if (result.isEmpty) return null;
        return _toUser(result.first);
      });

  @override
  Future<String?> passwordHashOf(String email) async =>
      runDb(op: 'users.passwordHashOf', () async {
        final result = await _conn.execute(
          Sql.named(
            'SELECT password_hash FROM users WHERE email = @email LIMIT 1',
          ),
          parameters: {'email': email},
        );
        if (result.isEmpty) return null;
        return result.first[0]! as String;
      });

  User _toUser(ResultRow row) => User(
        id: row[0]! as String,
        email: row[1]! as String,
        createdAt: row[2]! as DateTime,
      );
}
