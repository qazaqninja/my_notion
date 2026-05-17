import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';
import 'package:my_notion/features/sync/presentation/cubit/presence_cubit.dart';
import 'package:my_notion/features/sync/presentation/editor_ws_attach_controller.dart';

/// H2.4b — widget wrapper that owns one [EditorWsAttachController]
/// for the duration of one editor mount, reconciles it whenever the
/// gate inputs change, and publishes the controller to descendants
/// via [EditorSyncWsScope] so the editor's save path can call
/// `pushLocalUpdate` without prop-drilling.
///
/// Designed to be dropped into `editor_page.dart` between the
/// existing `MultiBlocListener` and the `_EditorBody` widget tree.
/// The host (H2.4c) extracts (isAuthed, token) from `SyncBloc` and
/// (isPublished) from the loaded page's frontmatter, then forwards
/// them as widget props — pure-presentational wrapper, no Bloc
/// reads of its own.
class EditorSyncWsMount extends StatefulWidget {
  const EditorSyncWsMount({
    super.key,
    required this.ulid,
    required this.isPublished,
    required this.isAuthed,
    required this.token,
    required this.initialBody,
    required this.binderFactory,
    required this.child,
    this.onRemoteDoc,
    this.onConnectionError,
  });

  /// Page ULID — drives the WS room. Changing this value tears
  /// down the existing binder and opens a fresh one.
  final String ulid;

  /// Frontmatter `public: true` flag — half of the gate.
  final bool isPublished;

  /// SyncBloc.state.isAuthed projection — half of the gate.
  final bool isAuthed;

  /// JWT token from the SyncBloc state. Null when unauthed; an
  /// empty string is also treated as missing (defensive).
  final String? token;

  /// Markdown body the editor mounted with. Becomes the binder's
  /// initial QuillCrdtDoc; later inbound peer updates and local
  /// pushes will replace it.
  final String initialBody;

  /// Factory closure that constructs a [SyncWsBinder] for the
  /// given (ulid, token, body). Injected so widget tests can stand
  /// up real binders backed by fake channels.
  final SyncWsBinderFactory binderFactory;

  /// Called whenever the active binder emits a new doc (inbound
  /// peer update OR local push). Editors typically use this to
  /// trigger a re-render of their body.
  final void Function(QuillCrdtDoc)? onRemoteDoc;

  /// Called on transport errors from the active binder (currently
  /// `SyncConnectionLostException`). Editors typically use this to
  /// show a "reconnect needed" banner.
  final void Function(Object)? onConnectionError;

  /// The editor body. Wrapped in an [EditorSyncWsScope] so any
  /// descendant can read the controller via
  /// `EditorSyncWsScope.maybeOf(context)`.
  final Widget child;

  @override
  State<EditorSyncWsMount> createState() => _EditorSyncWsMountState();
}

class _EditorSyncWsMountState extends State<EditorSyncWsMount> {
  late final EditorWsAttachController _controller;
  // H4d-iii-b — one PresenceCubit per editor mount. Owned here so
  // its TTL Timers are torn down with the editor, and exposed via
  // `BlocProvider<PresenceCubit>.value` so RemoteCursorOverlay
  // (M1454) can find it via BlocBuilder.
  late final PresenceCubit _presenceCubit;
  StreamSubscription<QuillCrdtDoc>? _docSub;
  StreamSubscription<Object>? _errSub;
  StreamSubscription<AwarenessMessage>? _awarenessSub;
  // Serialize reconciles so a rapid prop-change cascade (e.g. mount
  // → ulid swap during the first attach() await) doesn't interleave
  // concurrent calls into the controller, which would race
  // `_activeUlid` reads.
  Future<void> _reconcileChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _controller = EditorWsAttachController(binderFactory: widget.binderFactory);
    _presenceCubit = PresenceCubit();
    _docSub = _controller.docStream.listen((doc) {
      if (mounted) widget.onRemoteDoc?.call(doc);
    });
    _errSub = _controller.errorStream.listen((err) {
      if (mounted) widget.onConnectionError?.call(err);
    });
    _awarenessSub = _controller.awarenessStream.listen((msg) {
      // Forward to the cubit unconditionally; the cubit's own
      // isClosed guard handles the dispose race.
      _presenceCubit.remoteCursorReceived(msg);
    });
    _reconcile();
  }

  @override
  void didUpdateWidget(EditorSyncWsMount old) {
    super.didUpdateWidget(old);
    if (old.ulid != widget.ulid ||
        old.isPublished != widget.isPublished ||
        old.isAuthed != widget.isAuthed ||
        old.token != widget.token ||
        old.initialBody != widget.initialBody) {
      _reconcile();
    }
  }

  void _reconcile() {
    final authed = widget.isAuthed;
    final published = widget.isPublished;
    final ulid = widget.ulid;
    final token = widget.token;
    final initialBody = widget.initialBody;
    _reconcileChain = _reconcileChain
        .then(
          (_) => _controller.reconcile(
            authed: authed,
            published: published,
            ulid: ulid,
            token: token,
            initialBody: initialBody,
          ),
        )
        // Defensive: if `reconcile()` ever throws, the chain must
        // not be poisoned — a swallowed error here means the next
        // prop change still triggers a fresh reconcile. The
        // controller routes runtime errors through its
        // errorStream, so this catch is a guard against
        // programmer-error throws only.
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    // Fire-and-forget the async chain since State.dispose is sync.
    // Wrap in catchError so an unexpected dispose-time throw
    // doesn't bubble out as an unhandled future.
    unawaited(_docSub?.cancel());
    unawaited(_errSub?.cancel());
    unawaited(_awarenessSub?.cancel());
    unawaited(_presenceCubit.close());
    unawaited(_controller.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditorSyncWsScope(
      controller: _controller,
      child: BlocProvider<PresenceCubit>.value(
        value: _presenceCubit,
        child: widget.child,
      ),
    );
  }
}

/// InheritedWidget that publishes the [EditorWsAttachController]
/// from a [EditorSyncWsMount] to its descendants. Descendants call
/// `EditorSyncWsScope.maybeOf(context)?.pushLocalUpdate(body)` from
/// the editor's save path.
class EditorSyncWsScope extends InheritedWidget {
  const EditorSyncWsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final EditorWsAttachController controller;

  /// Read the controller from any descendant. Returns `null` when
  /// the editor is mounted outside an [EditorSyncWsMount] — local
  /// edits then silently skip the multiplayer broadcast.
  static EditorWsAttachController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<EditorSyncWsScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(EditorSyncWsScope old) =>
      controller != old.controller;
}
