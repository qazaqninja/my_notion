import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/presentation/default_editor_sync_binder_factory.dart';

void main() {
  group('defaultEditorSyncBinderFactory (H2.4d-i)', () {
    test('returns a SyncWsBinderFactory that constructs a SyncWsBinder',
        () async {
      final factory = defaultEditorSyncBinderFactory(wsUrl: 'ws://x:1234');
      final binder = factory(
        ulid: 'ULID-A',
        token: 'jwt-1',
        initialBody: 'line one\nline two',
      );
      expect(binder, isA<SyncWsBinder>());
      // initialDoc should reflect initialBody verbatim — this is
      // the contract the editor relies on: opening a published page
      // sees the same body the editor mounted with.
      expect(binder.doc.body, 'line one\nline two');
      await binder.dispose();
    });

    test('two calls return independent binders (no shared state)',
        () async {
      final factory = defaultEditorSyncBinderFactory(wsUrl: 'ws://x');
      final a = factory(ulid: 'A', token: 't', initialBody: 'aaa');
      final b = factory(ulid: 'B', token: 't', initialBody: 'bbb');
      expect(a.doc.body, 'aaa');
      expect(b.doc.body, 'bbb');
      expect(identical(a, b), isFalse);
      await a.dispose();
      await b.dispose();
    });

    test('empty initialBody produces an empty doc (clock 0)', () async {
      final factory = defaultEditorSyncBinderFactory(wsUrl: 'ws://x');
      final binder = factory(ulid: 'U', token: 't', initialBody: '');
      expect(binder.doc.body, '');
      expect(binder.doc.clock, 0);
      await binder.dispose();
    });
  });
}
