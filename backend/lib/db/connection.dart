import 'dart:io';

import 'package:postgres/postgres.dart';

/// Pool-backed Postgres connection for the backend server.
///
/// Reads `DATABASE_URL` from the environment (the docker-compose service
/// sets `postgres://quill:quill@postgres:5432/quill`). Falls back to a
/// localhost default for `dart run bin/server.dart` outside Docker.
///
/// Returns a single shared `Connection` for the process lifetime; the
/// caller is responsible for awaiting `close()` on shutdown.
Future<Connection> openDatabase({String? url}) async {
  final raw = url ?? Platform.environment['DATABASE_URL'] ??
      'postgres://quill:quill@localhost:5432/quill';
  final uri = Uri.parse(raw);
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.port == 0 ? 5432 : uri.port,
    database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'quill',
    username: uri.userInfo.split(':').first,
    password: uri.userInfo.contains(':')
        ? uri.userInfo.split(':').sublist(1).join(':')
        : '',
  );
  return Connection.open(
    endpoint,
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}
