import '../entities/sync_file.dart';

/// Outcome of a `put` call.
sealed class SyncPutOutcome {
  const SyncPutOutcome();
}

/// The put succeeded; the persisted summary is the server's canonical view.
class SyncPutSuccess extends SyncPutOutcome {
  const SyncPutSuccess(this.summary);
  final SyncFileSummary summary;
}

/// The put was rejected because `If-Match` didn't match the server's
/// current version. Clients should fetch [current] and reconcile.
class SyncPutConflict extends SyncPutOutcome {
  const SyncPutConflict(this.current);
  final SyncFileSummary current;
}

/// Auth + sync API contract. Implementations talk to the backend's
/// `/auth/*` and `/sync/*` endpoints; tests inject fakes.
abstract class SyncRepository {
  /// Log in with email + password. Returns the JWT to be used in
  /// `Authorization: Bearer <token>` headers for subsequent calls.
  /// Throws `SyncAuthException` on 401, `SyncNetworkException` on
  /// transport failure.
  Future<String> login({required String email, required String password});

  /// Same shape as login but creates the user. Throws
  /// `SyncEmailTakenException` on 409.
  Future<String> signup({required String email, required String password});

  /// List the caller's file summaries. Token must be from a prior
  /// successful login/signup.
  Future<List<SyncFileSummary>> list({required String token});

  /// Fetch a single file (summary + body) or null when not present.
  Future<SyncFileBody?> get({
    required String token,
    required String relpath,
  });

  /// Upsert [body] at [relpath]. When [ifMatch] is provided, the server
  /// only accepts the write if its current sha256 matches (or `*` for
  /// must-not-exist). On mismatch the outcome is a `SyncPutConflict`
  /// carrying the server's current summary.
  Future<SyncPutOutcome> put({
    required String token,
    required String relpath,
    required String body,
    String? ifMatch,
  });

  /// Delete a file. Returns true iff the server removed something
  /// (false ↔ 404).
  Future<bool> delete({required String token, required String relpath});

  /// E29 — backend liveness check. Hits `GET /health`. Returns `true`
  /// when the server is reachable AND its DB is connected (200 OK).
  /// `false` for 503 or any non-200. Throws `SyncNetworkException` for
  /// transport-layer failures (DNS, timeout, refused connection).
  /// Auth-agnostic — the endpoint does NOT require a token.
  Future<bool> ping();
}

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => 'SyncException: $message';
}

class SyncAuthException extends SyncException {
  const SyncAuthException([super.message = 'unauthorized']);
}

class SyncEmailTakenException extends SyncException {
  const SyncEmailTakenException([super.message = 'email_taken']);
}

class SyncNetworkException extends SyncException {
  const SyncNetworkException([super.message = 'network_error']);
}
