import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/presentation/editor_ws_attach_controller.dart';

/// H2.4d-i — production factory closure for the editor's
/// EditorSyncWsMount.binderFactory prop. Encapsulates the
/// SyncWsClient + SyncWsBinder construction so callers in other
/// features (notably the editor) don't need to import from
/// `sync/data/` directly. Tests substitute their own factory.
///
/// Why this lives in `sync/presentation/`: it's the canonical
/// production wiring for the editor's binderFactory prop, so it
/// belongs alongside the EditorSyncWsMount widget that consumes
/// it. The editor's presentation layer can then import only from
/// `sync/presentation/`, eliminating the cross-feature
/// presentation→data import that M1380/M1385 documented as the
/// CA-04 deferred cleanup.
SyncWsBinderFactory defaultEditorSyncBinderFactory({
  required String wsUrl,
}) {
  return ({
    required String ulid,
    required String token,
    required String initialBody,
  }) =>
      SyncWsBinder(
        client: SyncWsClient(wsUrl: wsUrl),
        ulid: ulid,
        token: token,
        initialDoc: QuillCrdtDoc.fromMarkdown(initialBody),
      );
}
