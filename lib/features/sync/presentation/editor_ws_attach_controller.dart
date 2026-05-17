import 'dart:async';

import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';

/// Factory closure that constructs a [SyncWsBinder] for the given
/// (ulid, token, initialBody) tuple. Injected so the controller's
/// tests can stand up real binders backed by fake WebSocketChannels
/// without standing up a real socket.
typedef SyncWsBinderFactory = SyncWsBinder Function({
  required String ulid,
  required String token,
  required String initialBody,
});

/// H2.4a — owns the [SyncWsBinder] lifecycle for one open editor.
/// The editor's State calls [reconcile] from any input that affects
/// the multiplayer gate (initial mount, SyncBloc state change,
/// publish/unpublish, switching to a different page), and the
/// controller decides whether to attach, detach, or swap the active
/// binder.
///
/// Gate: a binder is attached iff `authed && published && token`
/// is non-null. Any other combination tears down whatever was up.
///
/// Relayed surface:
/// - [docStream]: every doc emission from the active binder (incoming
///   peer updates + local pushes). Closed when the controller is
///   disposed.
/// - [errorStream]: transport errors from the active binder
///   (currently `SyncConnectionLostException`). Closed on dispose.
/// - [pushLocalUpdate]: proxy to the binder when attached; silent
///   no-op otherwise (the editor may call this during a tear-down
///   race).
///
/// H2.4b will instantiate this from `_EditorBodyState.initState`,
/// reconcile from `didUpdateWidget` + a `BlocListener<SyncBloc>`,
/// and dispose from `dispose`.
class EditorWsAttachController {
  EditorWsAttachController({required SyncWsBinderFactory binderFactory})
      : _binderFactory = binderFactory;

  final SyncWsBinderFactory _binderFactory;
  SyncWsBinder? _activeBinder;
  String? _activeUlid;
  StreamSubscription<QuillCrdtDoc>? _docSub;
  StreamSubscription<Object>? _errorSub;
  final _docController = StreamController<QuillCrdtDoc>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  bool _disposed = false;

  /// True iff a binder is currently attached.
  bool get isAttached => _activeBinder != null;

  /// ULID of the currently-attached page, or null when detached.
  String? get activeUlid => _activeUlid;

  /// Broadcast of doc updates from the active binder (incoming +
  /// local). Always safe to listen to — silent when no binder is
  /// attached.
  Stream<QuillCrdtDoc> get docStream => _docController.stream;

  /// Broadcast of transport errors from the active binder. Editors
  /// typically listen here to surface a "reconnect needed" banner.
  Stream<Object> get errorStream => _errorController.stream;

  /// Reconcile the controller's current state to the given gate
  /// inputs. Cheap to call repeatedly — when the (gate, ulid) tuple
  /// matches what's already attached, this is a no-op.
  Future<void> reconcile({
    required bool authed,
    required bool published,
    required String ulid,
    required String? token,
    required String initialBody,
  }) async {
    if (_disposed) return;
    final gateOpen = authed && published && token != null && token.isNotEmpty;
    if (!gateOpen) {
      await _detach();
      return;
    }
    if (_activeUlid == ulid && _activeBinder != null) {
      return; // already bound to this room
    }
    await _detach();
    final binder = _binderFactory(
      ulid: ulid,
      token: token,
      initialBody: initialBody,
    );
    _activeBinder = binder;
    _activeUlid = ulid;
    _docSub = binder.docStream.listen((doc) {
      if (!_docController.isClosed) _docController.add(doc);
    });
    _errorSub = binder.errorStream.listen((err) {
      if (!_errorController.isClosed) _errorController.add(err);
    });
    await binder.attach();
  }

  /// Proxy a local edit to the active binder. Silent no-op when
  /// detached — the editor may call this during a pre-attach or
  /// tear-down race.
  void pushLocalUpdate(String body) {
    _activeBinder?.pushLocalUpdate(body);
  }

  Future<void> _detach() async {
    final binder = _activeBinder;
    _activeBinder = null;
    _activeUlid = null;
    await _docSub?.cancel();
    _docSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    if (binder != null) {
      await binder.dispose();
    }
  }

  /// Tear down the active binder + close the relayed broadcast
  /// streams. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _detach();
    await _docController.close();
    await _errorController.close();
  }
}
