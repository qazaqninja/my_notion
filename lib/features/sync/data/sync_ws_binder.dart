import 'dart:async';

// Cross-feature import: pinned to crdt/domain/entities only — the
// stable value-type seam (QuillCrdtDoc + sealed QuillCrdtUpdate).
// Do NOT widen this to crdt/data or crdt/presentation (CA-07): the
// binder is allowed to know the CRDT entity shape but must never
// reach into the crdt feature's storage or UI layers.
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';

/// H2.3 — per-editor wiring between a [SyncWsClient] and a local
/// [QuillCrdtDoc]. One binder lives for the duration of one editor
/// mount: it [attach]es on `initState` (open the WS to
/// `/sync/sub/{ulid}`, subscribe to incoming messages, route each
/// to `QuillCrdtSetBody` on the local doc) and [detach]es on
/// `dispose` (cancel the subscription + close the client).
///
/// Local-side edits call [pushLocalUpdate] — the binder updates
/// its local doc *and* fans the new body out to peers via
/// `SyncWsClient.send`. Today the wire format is opaque text;
/// H2.4+ will swap to base64 y_crdt binary updates once the CRDT
/// seam stops being a pass-through.
///
/// Error propagation: a `SyncConnectionLostException` from the
/// underlying client (transport drop on an established session)
/// surfaces on [errorStream] so a host editor can show a
/// "reconnect needed" banner without coupling to the client's
/// exception types directly.
class SyncWsBinder {
  SyncWsBinder({
    required SyncWsClient client,
    required String ulid,
    required String token,
    required QuillCrdtDoc initialDoc,
  })  : _client = client,
        _ulid = ulid,
        _token = token,
        _doc = initialDoc;

  final SyncWsClient _client;
  final String _ulid;
  final String _token;

  QuillCrdtDoc _doc;
  StreamSubscription<String>? _incomingSub;
  final _docController = StreamController<QuillCrdtDoc>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final _awarenessController =
      StreamController<AwarenessMessage>.broadcast();
  bool _attached = false;

  /// Current local doc — always in sync with the last apply().
  QuillCrdtDoc get doc => _doc;

  /// Broadcast stream of new docs after every incoming peer update
  /// AND every [pushLocalUpdate]. Editors typically listen here to
  /// trigger a re-render.
  Stream<QuillCrdtDoc> get docStream => _docController.stream;

  /// Broadcast stream of transport errors (currently just
  /// [SyncConnectionLostException]). Editors typically listen here
  /// to flag a "reconnect needed" state.
  Stream<Object> get errorStream => _errorController.stream;

  /// H4d-i — broadcast stream of presence "awareness" messages
  /// parsed from the same `/sync/sub/<ulid>` channel. The wire
  /// dispatcher tries `AwarenessMessage.tryDecode(payload)` first;
  /// non-null payloads are routed here and never reach the CRDT
  /// path, so the host editor can subscribe directly without
  /// re-parsing or risking double-application on the doc.
  Stream<AwarenessMessage> get awarenessStream =>
      _awarenessController.stream;

  /// True iff [attach] has been called and [detach] hasn't.
  bool get isAttached => _attached;

  /// Open the WS to `/sync/sub/{ulid}` and start routing messages.
  /// Idempotent — a second call while already attached is a no-op.
  Future<void> attach() async {
    if (_attached) return;
    _attached = true;
    await _client.connect(token: _token, ulid: _ulid);
    _incomingSub = _client.incoming.listen(
      (payload) {
        // H4d-i — presence-first dispatch. Try parsing as an
        // AwarenessMessage envelope; on success route to the
        // awareness stream and short-circuit so the payload
        // never lands on the CRDT doc. On null (any non-
        // awareness payload — CRDT updates, malformed JSON,
        // mismatched kind) fall through to the existing path.
        final awareness = AwarenessMessage.tryDecode(payload);
        if (awareness != null) {
          if (!_awarenessController.isClosed) {
            _awarenessController.add(awareness);
          }
          return;
        }
        _doc = _doc.apply(QuillCrdtSetBody(payload));
        if (!_docController.isClosed) {
          _docController.add(_doc);
        }
      },
      onError: (Object error) {
        if (!_errorController.isClosed) {
          _errorController.add(error);
        }
      },
    );
  }

  /// Apply a local edit: update the local doc + broadcast to
  /// peers. Silent no-op when not attached (the editor may call
  /// this during a pre-mount race).
  void pushLocalUpdate(String body) {
    if (!_attached || !_client.isConnected) return;
    _doc = _doc.apply(QuillCrdtSetBody(body));
    if (!_docController.isClosed) {
      _docController.add(_doc);
    }
    _client.send(body);
  }

  /// Tear down: cancel the incoming subscription + close the
  /// client. Idempotent.
  Future<void> detach() async {
    if (!_attached) return;
    _attached = false;
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _client.close();
  }

  /// One-shot teardown of the broadcast streams too. Call once
  /// per binder instance (typically right after [detach] in the
  /// host's `dispose`).
  Future<void> dispose() async {
    await detach();
    await _docController.close();
    await _errorController.close();
    await _awarenessController.close();
  }
}
