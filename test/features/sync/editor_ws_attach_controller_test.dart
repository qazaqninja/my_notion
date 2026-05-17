import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_notion/features/sync/presentation/editor_ws_attach_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Hand-rolled channel matching the H2.2/H2.3 fakes — keeps the test
/// seam symmetric across the WS stack.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel();
  final inbound = StreamController<dynamic>.broadcast();
  final outbound = <Object?>[];

  @override
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _Sink(this);

  void simulateMessage(String s) => inbound.add(s);
  void simulateError(Object e) => inbound.addError(e);

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

/// A factory closure that records every (ulid, token, body) tuple a
/// controller passes to it so tests can assert on the call shape.
class _BinderFactoryRecorder {
  _BinderFactoryRecorder();

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
  group('EditorWsAttachController (H2.4a)', () {
    group('reconcile()', () {
      test('gate closed (unauthed) leaves the controller detached',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: false,
          published: true,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'hello',
        );
        expect(ctl.isAttached, isFalse);
        expect(rec.calls, isEmpty);
        await ctl.dispose();
      });

      test('gate closed (unpublished) leaves the controller detached',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: false,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'hello',
        );
        expect(ctl.isAttached, isFalse);
        expect(rec.calls, isEmpty);
        await ctl.dispose();
      });

      test('gate closed (no token) leaves the controller detached',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: null,
          initialBody: 'hello',
        );
        expect(ctl.isAttached, isFalse);
        expect(rec.calls, isEmpty);
        await ctl.dispose();
      });

      test('gate open attaches a binder with the right arguments',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-1',
          token: 'jwt-1',
          initialBody: 'init',
        );
        expect(ctl.isAttached, isTrue);
        expect(ctl.activeUlid, 'U-1');
        expect(rec.calls.single, {
          'ulid': 'U-1',
          'token': 'jwt-1',
          'initialBody': 'init',
        });
        await ctl.dispose();
      });

      test('reconcile with same ulid twice is a no-op (does not re-attach)',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'x',
        );
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'x',
        );
        expect(rec.calls.length, 1);
        await ctl.dispose();
      });

      test('reconcile to a different ulid detaches first, then re-attaches',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-1',
          token: 'jwt',
          initialBody: 'x',
        );
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-2',
          token: 'jwt',
          initialBody: 'y',
        );
        expect(rec.calls.length, 2);
        expect(rec.calls[0]['ulid'], 'U-1');
        expect(rec.calls[1]['ulid'], 'U-2');
        expect(ctl.activeUlid, 'U-2');
        await ctl.dispose();
      });

      test('flipping authed false after attach detaches the binder',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'x',
        );
        expect(ctl.isAttached, isTrue);
        await ctl.reconcile(
          authed: false,
          published: true,
          ulid: 'U',
          token: 'jwt',
          initialBody: 'x',
        );
        expect(ctl.isAttached, isFalse);
        expect(ctl.activeUlid, isNull);
        await ctl.dispose();
      });
    });

    group('relayed streams', () {
      test('docStream forwards incoming peer updates', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        final docs = <String>[];
        final sub = ctl.docStream.listen((d) => docs.add(d.body));
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: 'init',
        );
        rec.channels.single.simulateMessage('peer-edit');
        await pumpEventQueue();
        expect(docs, ['peer-edit']);
        await sub.cancel();
        await ctl.dispose();
      });

      test('errorStream forwards SyncConnectionLostException', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        final errors = <Object>[];
        final sub = ctl.errorStream.listen(errors.add);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: 'init',
        );
        rec.channels.single.simulateError('blip');
        await pumpEventQueue();
        expect(errors.single, isA<SyncConnectionLostException>());
        await sub.cancel();
        await ctl.dispose();
      });
    });

    group('pushLocalUpdate()', () {
      test('proxies to the attached binder', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        ctl.pushLocalUpdate('mine');
        expect(rec.channels.single.outbound, ['mine']);
        await ctl.dispose();
      });

      test('before attach is a silent no-op', () {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        // No reconcile() → no attach.
        ctl.pushLocalUpdate('orphan');
        expect(rec.channels, isEmpty);
      });
    });

    group('sendAwareness() (H4d-iii-d)', () {
      const msg = AwarenessMessage(
        userId: 'alice',
        pageUlid: 'U',
        cursorIndex: 42,
        color: '#FF5722',
      );

      test('proxies to the attached binder (encoded onto the WS sink)',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        ctl.sendAwareness(msg);
        await pumpEventQueue();
        expect(rec.channels.single.outbound, hasLength(1));
        expect(rec.channels.single.outbound.single, msg.encode());
        await ctl.dispose();
      });

      test('before attach is a silent no-op (no send, no throw)', () {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        ctl.sendAwareness(msg);
        expect(rec.channels, isEmpty);
      });

      test('after gate-close detach is a silent no-op', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        await ctl.reconcile(
          authed: false, // gate-close → detach
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        ctl.sendAwareness(msg);
        await pumpEventQueue();
        // The earlier channel's sink may have a recorded value
        // BEFORE detach, but the post-detach sendAwareness must
        // NOT have added anything.
        expect(rec.channels.single.outbound, isEmpty);
        await ctl.dispose();
      });
    });

    group('dispose()', () {
      test('idempotent + closes relayed streams', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        await ctl.dispose();
        // Second dispose() must not throw.
        await ctl.dispose();
        // Stream is closed → completes empty.
        final hasEvents = await ctl.docStream.isEmpty.timeout(
          const Duration(seconds: 1),
        );
        expect(hasEvents, isTrue);
      });

      test('closes awarenessStream (H4d-iii-a)', () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U',
          token: 't',
          initialBody: '',
        );
        await ctl.dispose();
        final hasEvents = await ctl.awarenessStream.isEmpty.timeout(
          const Duration(seconds: 1),
        );
        expect(hasEvents, isTrue);
      });
    });

    group('awarenessStream (H4d-iii-a)', () {
      const awarenessJson =
          '{"kind":"awareness","userId":"alice","pageUlid":"U-1",'
          '"cursorIndex":7,"color":"#FF5722"}';

      test('relays parsed awareness from the active binder',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        final received = <int>[];
        final sub = ctl.awarenessStream
            .listen((msg) => received.add(msg.cursorIndex));
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-1',
          token: 'jwt',
          initialBody: '',
        );
        // Drive the underlying fake channel — the binder routes
        // through its own awareness dispatcher (M1457 H4d-i) and
        // the controller relays via the new subscription.
        rec.channels.last.simulateMessage(awarenessJson);
        await pumpEventQueue();
        expect(received, [7]);
        await sub.cancel();
        await ctl.dispose();
      });

      test('does NOT emit on docStream (presence is not a doc update)',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        final docBodies = <String>[];
        final sub =
            ctl.docStream.listen((d) => docBodies.add(d.body));
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-1',
          token: 'jwt',
          initialBody: 'initial',
        );
        rec.channels.last.simulateMessage(awarenessJson);
        await pumpEventQueue();
        // No CRDT doc body should change from the awareness msg.
        expect(docBodies, isEmpty);
        await sub.cancel();
        await ctl.dispose();
      });

      test('after ulid swap, only the new binder feeds awarenessStream',
          () async {
        final rec = _BinderFactoryRecorder();
        final ctl = EditorWsAttachController(binderFactory: rec.make);
        final received = <String>[];
        final sub = ctl.awarenessStream
            .listen((msg) => received.add(msg.userId));
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-1',
          token: 'jwt',
          initialBody: '',
        );
        await ctl.reconcile(
          authed: true,
          published: true,
          ulid: 'U-2', // forces detach + re-attach
          token: 'jwt',
          initialBody: '',
        );
        // The old channel was closed by the binder's dispose at
        // detach time, proving the subscription was cancelled.
        // The new binder's channel still flows.
        rec.channels.last.simulateMessage(
            '{"kind":"awareness","userId":"bob","pageUlid":"U-2",'
            '"cursorIndex":1,"color":"#00FF00"}');
        await pumpEventQueue();
        expect(received, ['bob']);
        await sub.cancel();
        await ctl.dispose();
      });
    });
  });
}
