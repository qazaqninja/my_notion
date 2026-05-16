import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/middleware.dart';
import '../db/sync.dart';

/// Build the `/sync/...` sub-router. Caller mounts at `/sync` *after*
/// wrapping with `requireAuth` so `currentUser(req)` is safe to call.
///
/// Routes (cumulative across slices):
/// - `GET /sync/list` — caller's vault file summary array. Slice E8.
/// - `PUT /sync/put/[relpath]` — upsert a file (raw body). Slice E9.
/// - `GET /sync/get/[relpath]` — fetch body + sha256 + mtime. Slice E10.
/// - (E11+) DELETE, conflict detection, etc.
Router buildSyncRouter({required SyncRepositoryBase sync}) {
  final router = Router();

  router.get('/list', (Request req) async {
    final user = currentUser(req);
    final files = await sync.listFor(user.id);
    return Response.ok(
      jsonEncode([for (final f in files) f.toJson()]),
      headers: const {'content-type': 'application/json'},
    );
  });

  router.get('/get/<relpath|.*>', (Request req) async {
    final user = currentUser(req);
    final relpath = req.params['relpath'];
    if (relpath == null || relpath.isEmpty) {
      return _err(400, 'missing_relpath');
    }
    if (!_isSafeRelpath(relpath)) {
      return _err(400, 'invalid_relpath');
    }
    final file = await sync.fetch(userId: user.id, relpath: relpath);
    if (file == null) {
      return _err(404, 'not_found');
    }
    return Response.ok(
      jsonEncode(file.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  });

  // `PUT /put/<relpath...>` — `relpath` is captured as the suffix of the
  // URL after `/put/`. The body is the raw markdown source; we compute
  // sha256 server-side so the canonical hash is authoritative.
  router.put('/put/<relpath|.*>', (Request req) async {
    final user = currentUser(req);
    final relpath = req.params['relpath'];
    if (relpath == null || relpath.isEmpty) {
      return _err(400, 'missing_relpath');
    }
    if (!_isSafeRelpath(relpath)) {
      return _err(400, 'invalid_relpath');
    }
    final body = await req.readAsString();
    final hash = sha256.convert(utf8.encode(body)).toString();
    final summary = await sync.upsert(
      userId: user.id,
      relpath: relpath,
      body: body,
      sha256: hash,
    );
    return Response.ok(
      jsonEncode(summary.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  });

  return router;
}

/// Reject path-traversal (`..` segments), absolute paths, and any leading
/// slash so callers can't break out of their per-user namespace by
/// crafting a relpath like `../bob/secret.md`. Empty segments are also
/// rejected — they're an attack vector on some filesystem mirrors.
bool _isSafeRelpath(String relpath) {
  if (relpath.startsWith('/')) return false;
  final segments = relpath.split('/');
  for (final s in segments) {
    if (s.isEmpty) return false;
    if (s == '.' || s == '..') return false;
  }
  return true;
}

Response _err(int status, String code) => Response(
      status,
      body: jsonEncode({'error': code}),
      headers: const {'content-type': 'application/json'},
    );
