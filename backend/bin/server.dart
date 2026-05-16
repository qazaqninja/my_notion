import 'dart:io';

import 'package:backend/auth/middleware.dart';
import 'package:backend/auth/password.dart';
import 'package:backend/auth/routes.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/db/connection.dart';
import 'package:backend/db/migrations.dart';
import 'package:backend/db/sync.dart';
import 'package:backend/db/users.dart';
import 'package:backend/sync/routes.dart' as sync_routes;
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

/// Single shared connection. `null` until openDatabase() resolves or
/// `DATABASE_URL` is missing (allowed in plain `dart run` mode so
/// `bin/server.dart` still boots without a DB).
Connection? _conn;

Response _rootHandler(Request req) => Response.ok('Hello, World!\n');

Response _echoHandler(Request req) {
  final message = req.params['message'];
  return Response.ok('$message\n');
}

Future<Response> _healthHandler(Request req) async {
  final conn = _conn;
  if (conn == null) {
    return Response(503, body: 'db: not connected\n');
  }
  try {
    final row = await conn.execute('SELECT 1');
    if (row.isEmpty) {
      return Response(503, body: 'db: empty response\n');
    }
    return Response.ok('ok\n');
  } catch (e) {
    return Response(503, body: 'db: $e\n');
  }
}

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;

  // Try to connect to Postgres on boot. If the DB isn't reachable we
  // continue anyway so `/health` can report the failure rather than
  // crashing the process — friendlier dev UX.
  try {
    _conn = await openDatabase();
    await runMigrations(_conn!);
    stdout.writeln('database: connected + migrations applied');
  } catch (e) {
    stderr.writeln('database: failed to connect ($e). /health will report.');
  }

  final router = Router()
    ..get('/', _rootHandler)
    ..get('/echo/<message>', _echoHandler)
    ..get('/health', _healthHandler);

  // Auth + sync sub-routers — only mounted when the DB is up. Without a
  // connection, /auth/* and /sync/* return 503 via a fallback shim so
  // clients see a clean error rather than a stack trace.
  final conn = _conn;
  if (conn != null) {
    final users = UserRepository(conn);
    final tokens = TokenIssuer();
    router.mount(
      '/auth/',
      buildAuthRouter(
        users: users,
        hasher: const PasswordHasher(),
        tokens: tokens,
      ).call,
    );
    final syncPipeline = Pipeline()
        .addMiddleware(requireAuth(users: users, tokens: tokens))
        .addHandler(
          sync_routes
              .buildSyncRouter(sync: SyncRepository(conn))
              .call,
        );
    router.mount('/sync/', syncPipeline);
  } else {
    router.all('/auth/<ignored|.*>',
        (Request req) => Response(503, body: 'db: not connected\n'));
    router.all('/sync/<ignored|.*>',
        (Request req) => Response(503, body: 'db: not connected\n'));
  }

  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  stdout.writeln('Server listening on port ${server.port}');
}
