import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/sync/data/sync_ws_binder.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Hand-rolled fake — mirrors the SyncWsClient test's fake so the
/// two layers are exercised against the same protocol shape.
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

SyncWsClient _makeClient({_FakeChannel? out}) {
  return SyncWsClient(
    wsUrl: 'ws://x',
    channelFactory: ({
      required String wsUrl,
      required String token,
      required String ulid,
    }) =>
        out ?? _FakeChannel(),
  );
}

void main() {
  group('SyncWsBinder (H2.3)', () {
    group('attach()', () {
      test('connects the WS client to the configured ULID + token',
          () async {
        final ch = _FakeChannel();
        String? capturedToken;
        String? capturedUlid;
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) {
            capturedToken = token;
            capturedUlid = ulid;
            return ch;
          },
        );
        final binder = SyncWsBinder(
          client: client,
          ulid: 'ULID-1',
          token: 'jwt',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        expect(capturedToken, 'jwt');
        expect(capturedUlid, 'ULID-1');
        expect(client.isConnected, isTrue);
        await binder.detach();
      });

      test('second attach() is a no-op when already attached', () async {
        final openedUlids = <String>[];
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) {
            openedUlids.add(ulid);
            return _FakeChannel();
          },
        );
        final binder = SyncWsBinder(
          client: client,
          ulid: 'ULID-1',
          token: 'jwt',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        await binder.attach();
        expect(openedUlids, ['ULID-1']);
        await binder.detach();
      });
    });

    group('incoming → CRDT', () {
      test('incoming text applies QuillCrdtSetBody to the local doc',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.fromMarkdown('hello'),
        );
        await binder.attach();
        expect(binder.doc.body, 'hello');
        ch.simulateMessage('from peer 1');
        await pumpEventQueue();
        expect(binder.doc.body, 'from peer 1');
        expect(binder.doc.clock, greaterThan(0));
        ch.simulateMessage('from peer 2');
        await pumpEventQueue();
        expect(binder.doc.body, 'from peer 2');
        await binder.detach();
      });

      test('docStream emits each new doc after an incoming message',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        final emitted = <String>[];
        final sub = binder.docStream.listen((d) => emitted.add(d.body));
        await binder.attach();
        ch.simulateMessage('a');
        ch.simulateMessage('b');
        ch.simulateMessage('c');
        await pumpEventQueue();
        expect(emitted, ['a', 'b', 'c']);
        await sub.cancel();
        await binder.detach();
      });
    });

    group('pushLocalUpdate()', () {
      test('writes the new body to the channel sink', () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        binder.pushLocalUpdate('local edit');
        expect(ch.outbound, ['local edit']);
        await binder.detach();
      });

      test('updates the local doc + emits on docStream', () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        final emitted = <String>[];
        final sub = binder.docStream.listen((d) => emitted.add(d.body));
        binder.pushLocalUpdate('mine');
        await pumpEventQueue();
        expect(binder.doc.body, 'mine');
        expect(emitted, ['mine']);
        await sub.cancel();
        await binder.detach();
      });

      test('before attach() is a silent no-op (no throw, no send)', () {
        final ch = _FakeChannel();
        final binder = SyncWsBinder(
          client: _makeClient(out: ch),
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        // Should not throw, should not crash, but also should not
        // hit the underlying sink — a local edit before attach is
        // typically a pre-mount race the editor doesn't want to
        // hard-fail on.
        binder.pushLocalUpdate('orphan');
        expect(ch.outbound, isEmpty);
      });
    });

    group('errors', () {
      test('connection-lost from the channel is exposed on errorStream',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        final errors = <Object>[];
        final sub = binder.errorStream.listen(errors.add);
        await binder.attach();
        ch.simulateError('boom');
        await pumpEventQueue();
        expect(errors.single, isA<SyncConnectionLostException>());
        await sub.cancel();
        await binder.detach();
      });
    });

    group('detach()', () {
      test('disconnects the client + is idempotent', () async {
        final client = _makeClient();
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        expect(client.isConnected, isTrue);
        await binder.detach();
        expect(client.isConnected, isFalse);
        // Second detach() must not throw.
        await binder.detach();
      });
    });

    group('dispose()', () {
      test('cold dispose (no prior attach) closes streams cleanly',
          () async {
        final binder = SyncWsBinder(
          client: _makeClient(),
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        // Should not throw — covers the editor-tears-down-before-mount
        // race that the F2 IncomingShareBinder also has to handle.
        await binder.dispose();
        // Listening to a closed broadcast controller returns a stream
        // that yields no events and completes; expect a `done` event
        // immediately.
        final hasEvents =
            await binder.docStream.isEmpty.timeout(const Duration(seconds: 1));
        expect(hasEvents, isTrue);
      });

      test('warm dispose (after attach + push) closes streams cleanly',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        binder.pushLocalUpdate('warm');
        await pumpEventQueue();
        await binder.dispose();
        expect(client.isConnected, isFalse);
        // dispose() must be idempotent.
        await binder.dispose();
      });
    });

    group('awarenessStream (H4d-i)', () {
      const awarenessJson =
          '{"kind":"awareness","userId":"alice","pageUlid":"U",'
          '"cursorIndex":42,"color":"#FF5722"}';

      test('parsed awareness payload is routed to awarenessStream',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        final received = <int>[];
        final sub = binder.awarenessStream
            .listen((msg) => received.add(msg.cursorIndex));
        await binder.attach();
        ch.simulateMessage(awarenessJson);
        await pumpEventQueue();
        expect(received, [42]);
        await sub.cancel();
        await binder.dispose();
      });

      test('awareness payload does NOT reach the CRDT doc',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.fromMarkdown('original'),
        );
        await binder.attach();
        ch.simulateMessage(awarenessJson);
        await pumpEventQueue();
        // Doc body unchanged; awareness short-circuited the dispatch.
        expect(binder.doc.body, 'original');
        await binder.dispose();
      });

      test('opaque (non-awareness) payload still goes to the CRDT path',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        final awarenessReceived = <Object?>[];
        final sub =
            binder.awarenessStream.listen(awarenessReceived.add);
        await binder.attach();
        ch.simulateMessage('opaque crdt blob');
        await pumpEventQueue();
        expect(binder.doc.body, 'opaque crdt blob');
        expect(awarenessReceived, isEmpty);
        await sub.cancel();
        await binder.dispose();
      });

      test('mixed stream — awareness + CRDT routed to their own paths',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        final awarenessReceived = <String>[];
        final docBodies = <String>[];
        final aSub = binder.awarenessStream
            .listen((m) => awarenessReceived.add(m.userId));
        final dSub =
            binder.docStream.listen((d) => docBodies.add(d.body));
        await binder.attach();
        ch.simulateMessage(awarenessJson); // alice cursor
        ch.simulateMessage('crdt body 1');
        ch.simulateMessage(
            '{"kind":"awareness","userId":"bob","pageUlid":"U",'
            '"cursorIndex":7,"color":"#00FF00"}');
        ch.simulateMessage('crdt body 2');
        await pumpEventQueue();
        expect(awarenessReceived, ['alice', 'bob']);
        expect(docBodies, ['crdt body 1', 'crdt body 2']);
        await aSub.cancel();
        await dSub.cancel();
        await binder.dispose();
      });

      test('mismatched-kind JSON falls through to the CRDT path',
          () async {
        final ch = _FakeChannel();
        final client = _makeClient(out: ch);
        final binder = SyncWsBinder(
          client: client,
          ulid: 'U',
          token: 't',
          initialDoc: QuillCrdtDoc.empty(),
        );
        await binder.attach();
        // Mismatched kind → tryDecode returns null → CRDT path.
        ch.simulateMessage(
            '{"kind":"update","payload":"abc"}');
        await pumpEventQueue();
        expect(
            binder.doc.body, '{"kind":"update","payload":"abc"}');
        await binder.dispose();
      });
    });
  });
}
