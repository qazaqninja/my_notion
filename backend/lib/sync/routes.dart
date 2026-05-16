import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/middleware.dart';
import '../db/sync.dart';

/// Build the `/sync/...` sub-router. Caller mounts at `/sync` *after*
/// wrapping with `requireAuth` so `currentUser(req)` is safe to call.
///
/// Routes (cumulative across slices):
/// - `GET /sync/list` — returns the caller's vault file summary as JSON
///   array `[{relpath, sha256, mtime}, …]`. Slice E8.
/// - (E9) `PUT /sync/put/[relpath]` — upsert a file.
/// - (E10) `GET /sync/get/[relpath]` — fetch body.
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

  return router;
}
