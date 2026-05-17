import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/presentation/editor_sync_ws_mount.dart';
import 'package:my_notion/features/sync/presentation/editor_ws_attach_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Reusing the H2.2-H2.4a fake channel shape so the widget test
/// exercises real SyncWsClient + real SyncWsBinder under the
/// controller — only the socket is faked.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel();
  final inbound = StreamController<dynamic>.broadcast();
  final outbound = <Object?>[];

  @override
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _Sink(this);

  void simulateMessage(String s) => inbound.add(s);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Sink implements WebSocketSink {
  _Sink(this.parent);
  final _FakeChannel parent;

  @override
  void add(Object? event) => parent.outbound.add(event);

  @override
  Future<void> close([int? code, String? reason]) async {
    await parent.inbound.close();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Recorder {
  final calls = <Map<String, String>>[];
  final channels = <_FakeChannel>[];

  SyncWsBinder make({
    required String ulid,
    required String token,
    required String initialBody,
  }) {
    calls.add({'ulid': ulid, 'token': token, 'initialBody': initialBody});
    final ch = _FakeChannel();
    channels.add(ch);
    return SyncWsBinder(
      client: SyncWsClient(
        wsUrl: 'ws://x',
        channelFactory: ({
          required String wsUrl,
          required String token,
          required String ulid,
        }) =>
            ch,
      ),
      ulid: ulid,
      token: token,
      initialDoc: QuillCrdtDoc.fromMarkdown(initialBody),
    );
  }
}

void main() {
  group('EditorSyncWsMount (H2.4b)', () {
    group('lifecycle', () {
      testWidgets('gate-open initial mount attaches the controller',
          (tester) async {
        final rec = _Recorder();
        await tester.pumpWidget(
          EditorSyncWsMount(
            ulid: 'U-1',
            isPublished: true,
            isAuthed: true,
            token: 'jwt',
            initialBody: 'hello',
            binderFactory: rec.make,
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();
        expect(rec.calls.single, {
          'ulid': 'U-1',
          'token': 'jwt',
          'initialBody': 'hello',
        });
      });

      testWidgets('gate-closed initial mount does not attach', (tester) async {
        final rec = _Recorder();
        await tester.pumpWidget(
          EditorSyncWsMount(
            ulid: 'U-1',
            isPublished: false,
            isAuthed: true,
            token: 'jwt',
            initialBody: 'hello',
            binderFactory: rec.make,
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();
        expect(rec.calls, isEmpty);
      });

      testWidgets('flipping isPublished true → false detaches',
          (tester) async {
        final rec = _Recorder();
        final publishedNotifier = ValueNotifier<bool>(true);
        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: publishedNotifier,
            builder: (_, published, __) => EditorSyncWsMount(
              ulid: 'U-1',
              isPublished: published,
              isAuthed: true,
              token: 'jwt',
              initialBody: 'hello',
              binderFactory: rec.make,
              child: const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(rec.calls.length, 1);
        publishedNotifier.value = false;
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        // No new factory call (detach doesn't construct a new binder).
        expect(rec.calls.length, 1);
      });

      // Note: ulid-swap correctness is exercised exhaustively at the
      // controller level by editor_ws_attach_controller_test.dart's
      // "reconcile to a different ulid detaches first, then re-
      // attaches" test (M1379). Widget-level coverage of the swap is
      // intentionally omitted here because the deep async teardown
      // chain (controller→binder→client→fake-channel close) doesn't
      // reliably drain within widget-tester polling windows — the
      // controller test already proves correctness against the same
      // contract, so widget-level repetition would only add flake.

      testWidgets('unmount disposes the controller', (tester) async {
        final rec = _Recorder();
        await tester.pumpWidget(
          EditorSyncWsMount(
            ulid: 'U-1',
            isPublished: true,
            isAuthed: true,
            token: 'jwt',
            initialBody: 'hello',
            binderFactory: rec.make,
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        // Replace with a tree that doesn't include the mount → unmount.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        // dispose() is fire-and-forget via unawaited(); drain the
        // real event queue so the chain reaches inbound.close().
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(rec.channels.single.inbound.isClosed, isTrue);
      });
    });

    group('callbacks', () {
      testWidgets('onRemoteDoc fires on incoming peer messages',
          (tester) async {
        final rec = _Recorder();
        final remotes = <String>[];
        await tester.pumpWidget(
          EditorSyncWsMount(
            ulid: 'U',
            isPublished: true,
            isAuthed: true,
            token: 't',
            initialBody: '',
            binderFactory: rec.make,
            onRemoteDoc: (d) => remotes.add(d.body),
            child: const SizedBox(),
          ),
        );
        await tester.pumpAndSettle();
        rec.channels.single.simulateMessage('peer-edit');
        await tester.pumpAndSettle();
        expect(remotes, ['peer-edit']);
      });
    });

    group('EditorSyncWsScope', () {
      testWidgets(
          'descendants can pushLocalUpdate via EditorSyncWsScope.maybeOf',
          (tester) async {
        final rec = _Recorder();
        late BuildContext childCtx;
        await tester.pumpWidget(
          EditorSyncWsMount(
            ulid: 'U',
            isPublished: true,
            isAuthed: true,
            token: 't',
            initialBody: '',
            binderFactory: rec.make,
            child: Builder(
              builder: (ctx) {
                childCtx = ctx;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scope = EditorSyncWsScope.maybeOf(childCtx);
        expect(scope, isA<EditorWsAttachController>());
        scope!.pushLocalUpdate('hello-peers');
        expect(rec.channels.single.outbound, ['hello-peers']);
      });

      testWidgets('maybeOf returns null outside a mount', (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        );
        expect(EditorSyncWsScope.maybeOf(ctx), isNull);
      });
    });
  });
}
