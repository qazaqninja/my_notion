import 'package:backend/auth/middleware.dart';
import 'package:backend/sync/ws_hub.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

/// H2 — `/sync/sub/<ulid>` WebSocket subscription endpoint.
///
/// Wire format: every message is a `String` (CRDT updates that will
/// eventually be y_crdt binary should be base64-encoded for now so
/// the channel stays text-only; the hub doesn't inspect contents).
///
/// Auth: the wrapping pipeline already runs `requireAuth`, so
/// `currentUser(req)` resolves the user from the Bearer JWT. The
/// WebSocket upgrade request comes through the same shelf request
/// pipeline so the auth middleware fires before the upgrade.
///
/// Mounted at `/sub/` by `buildSyncRouter`, which itself mounts at
/// `/sync/` in server.dart. So the public path is `/sync/sub/<ulid>`.
Router buildWsRouter({required WsHub hub}) {
  final router = Router();

  router.get('/<ulid>', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    final user = currentUser(req);

    final handler = webSocketHandler((webSocket, protocol) {
      hub.subscribe(
        userId: user.id,
        pageUlid: ulid,
        channel: webSocket,
      );
      webSocket.stream.listen(
        (message) {
          // Fan out raw payload to every other subscriber of the
          // same (user, ulid) room. Body is opaque to the hub —
          // present-slice clients exchange JSON strings; H2.3+ will
          // switch to y_crdt binary updates.
          if (message is String) {
            hub.broadcast(
              userId: user.id,
              pageUlid: ulid,
              from: webSocket,
              payload: message,
            );
          }
        },
        onDone: () => hub.unsubscribe(webSocket),
        onError: (_) => hub.unsubscribe(webSocket),
        cancelOnError: true,
      );
    });
    return handler(req);
  });

  return router;
}

bool _isUlid(String s) =>
    RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s);
