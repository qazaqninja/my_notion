import 'dart:async';

import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Test seam for SyncWsClient — abstracts the WebSocketChannel
/// open call so tests can inject a fake without standing up a
/// real socket. The default impl uses `WebSocketChannel.connect`
/// from `package:web_socket_channel`.
typedef SyncWsChannelFactory = WebSocketChannel Function({
  required String wsUrl,
  required String token,
  required String ulid,
});

WebSocketChannel _defaultChannelFactory({
  required String wsUrl,
  required String token,
  required String ulid,
}) {
  // The WebSocket upgrade can't set arbitrary headers cross-platform
  // (web won't), so the Bearer token is appended as a query param.
  // The backend's wsRoute middleware reads `?token=` as an
  // alternative to `Authorization: Bearer`.
  final uri = Uri.parse('$wsUrl/sync/sub/$ulid?token=$token');
  return WebSocketChannel.connect(uri);
}

/// H2.2 — opens a single WebSocket to `/sync/sub/<ulid>`, exposes
/// `incoming` as a broadcast stream of decoded text messages and
/// `send(payload)` to push to peers in the same room. Lifecycle:
/// caller invokes `connect()` once per editor mount, then `close()`
/// on unmount.
///
/// Message wire format is opaque text today (H2.3 swaps to base64-
/// encoded y_crdt binary updates once the CRDT seam stops being a
/// pass-through).
class SyncWsClient {
  SyncWsClient({
    required this.wsUrl,
    SyncWsChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? _defaultChannelFactory;

  /// Base WebSocket URL — e.g. `ws://localhost:8080` (no trailing
  /// slash). The client appends `/sync/sub/<ulid>?token=<jwt>`.
  final String wsUrl;
  final SyncWsChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  String? _ulid;
  final _incomingController = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _channelSub;

  /// True iff the client is currently connected to a room.
  bool get isConnected => _channel != null;

  /// Currently-subscribed page ULID, or null when disconnected.
  String? get currentUlid => _ulid;

  /// Broadcast stream of inbound text messages from peers. Always
  /// safe to listen to — emits when a connection is open and is
  /// silent otherwise.
  Stream<String> get incoming => _incomingController.stream;

  /// Connect to the room for [ulid]. Idempotent on the same
  /// (token, ulid): a second call replaces the channel.
  Future<void> connect({
    required String token,
    required String ulid,
  }) async {
    await close();
    final channel = _channelFactory(
      wsUrl: wsUrl,
      token: token,
      ulid: ulid,
    );
    _channel = channel;
    _ulid = ulid;
    _channelSub = channel.stream.listen(
      (event) {
        if (event is String) {
          _incomingController.add(event);
        }
      },
      onDone: () {
        // Server-initiated close — drop refs so a future connect()
        // starts cleanly.
        _channel = null;
        _ulid = null;
        _channelSub = null;
      },
      onError: (Object error) {
        // Transport-level failure on an established connection —
        // forward a typed error so the Bloc can transition to a
        // "reconnect needed" state rather than the stream going
        // silently quiet.
        _channel = null;
        _ulid = null;
        _channelSub = null;
        if (!_incomingController.isClosed) {
          _incomingController.addError(
            SyncConnectionLostException(error.toString()),
          );
        }
      },
      cancelOnError: true,
    );
  }

  /// Send [payload] to every other subscriber of the current room.
  /// Throws [StateError] when not connected so caller bugs surface
  /// immediately rather than getting silently dropped.
  void send(String payload) {
    final channel = _channel;
    if (channel == null) {
      throw StateError(
        'SyncWsClient.send called while not connected — '
        'caller must invoke connect() first',
      );
    }
    channel.sink.add(payload);
  }

  /// Disconnect from the current room (if any). Idempotent.
  Future<void> close() async {
    await _channelSub?.cancel();
    _channelSub = null;
    final ch = _channel;
    _channel = null;
    _ulid = null;
    if (ch != null) {
      await ch.sink.close();
    }
  }

  /// Tears down the broadcast stream too. Call once per client
  /// instance (typically from the host's `dispose`).
  Future<void> dispose() async {
    await close();
    await _incomingController.close();
  }
}
