/// Typed exception hierarchy for backend repository boundaries.
/// Route handlers catch [DbUnavailableException] and map it to 503; raw
/// `package:postgres` errors should never escape a repo method (closes
/// the RP-03 / Phase-E-audit deferred item).
class DbException implements Exception {
  const DbException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => 'DbException: $message';
}

/// The database refused or dropped the query: connection lost,
/// transient lock contention, etc. Maps to HTTP 503 at the route
/// layer.
class DbUnavailableException extends DbException {
  const DbUnavailableException(super.message, {super.cause});
}

/// Generic runner that wraps a [body] doing one or more `_conn.execute`
/// calls in a try/catch and rethrows transport-layer failures as a
/// [DbUnavailableException]. Repo methods use this to keep raw
/// `package:postgres` errors from leaking past the boundary.
///
/// Caller-thrown [DbException] subtypes pass through untouched so a
/// repo can short-circuit with a domain-specific failure (e.g.
/// `EmailAlreadyTakenException`) and the route layer can still
/// distinguish it.
Future<T> runDb<T>(
  Future<T> Function() body, {
  String op = 'query',
}) async {
  try {
    return await body();
  } on DbException {
    rethrow;
  } catch (e) {
    throw DbUnavailableException('$op failed: $e', cause: e);
  }
}
