import 'dart:async';

import 'package:backend/sync/ws_hub.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// H2.1 — in-memory hub tests. Uses a hand-rolled FakeChannel that
/// only implements the `WebSocketChannel.sink.add` half of the
/// contract the hub touches, so we don't need a real socket pair.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel(this.label);
  final String label;
  final received = <String>[];

  @override
  WebSocketSink get sink => _Sink(received);

  // The hub never reads these — give them throwers so accidental
  // wider usage is loud.
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Sink implements WebSocketSink {
  _Sink(this.received);
  final List<String> received;

  @override
  void add(Object? event) => received.add(event! as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('WsHub (H2)', () {
    test('subscribe then broadcast fans out to every other peer in the room',
        () async {
      final hub = WsHub();
      final alice1 = _FakeChannel('alice1');
      final alice2 = _FakeChannel('alice2');
      final alice3 = _FakeChannel('alice3');
      hub
        ..subscribe(userId: 'alice', pageUlid: 'ULID1', channel: alice1)
        ..subscribe(userId: 'alice', pageUlid: 'ULID1', channel: alice2)
        ..subscribe(userId: 'alice', pageUlid: 'ULID1', channel: alice3);

      final sent = hub.broadcast(
        userId: 'alice',
        pageUlid: 'ULID1',
        from: alice1,
        payload: 'hello-from-alice1',
      );
      expect(sent, 2);
      expect(alice2.received, ['hello-from-alice1']);
      expect(alice3.received, ['hello-from-alice1']);
      // The originator does NOT receive their own message.
      expect(alice1.received, isEmpty);
    });

    test('Different rooms do not cross-talk', () {
      final hub = WsHub();
      final a = _FakeChannel('a');
      final b = _FakeChannel('b');
      hub
        ..subscribe(userId: 'alice', pageUlid: 'ULID1', channel: a)
        ..subscribe(userId: 'alice', pageUlid: 'ULID2', channel: b)
        ..broadcast(
          userId: 'alice',
          pageUlid: 'ULID1',
          from: a,
          payload: 'only-room-1',
        );
      expect(b.received, isEmpty);
    });

    test('Different users do not cross-talk even on same ULID', () {
      final hub = WsHub();
      final aliceCh = _FakeChannel('alice');
      final bobCh = _FakeChannel('bob');
      hub
        ..subscribe(userId: 'alice', pageUlid: 'ULID', channel: aliceCh)
        ..subscribe(userId: 'bob', pageUlid: 'ULID', channel: bobCh)
        ..broadcast(
          userId: 'alice',
          pageUlid: 'ULID',
          from: aliceCh,
          payload: 'alice-only',
        );
      expect(bobCh.received, isEmpty);
      // Cross-direction too.
      hub.broadcast(
        userId: 'bob',
        pageUlid: 'ULID',
        from: bobCh,
        payload: 'bob-only',
      );
      expect(aliceCh.received, isEmpty);
    });

    test('broadcast to a room with no subscribers returns 0', () {
      final hub = WsHub();
      final ch = _FakeChannel('ghost');
      // Note: `ch` is NOT subscribed.
      final sent = hub.broadcast(
        userId: 'alice',
        pageUlid: 'NO-ULID',
        from: ch,
        payload: 'into-the-void',
      );
      expect(sent, 0);
    });

    test('unsubscribe removes the channel from every room', () {
      final hub = WsHub();
      final a = _FakeChannel('a');
      final b = _FakeChannel('b');
      hub
        ..subscribe(userId: 'alice', pageUlid: 'X', channel: a)
        ..subscribe(userId: 'alice', pageUlid: 'Y', channel: a)
        ..subscribe(userId: 'alice', pageUlid: 'X', channel: b);
      expect(hub.subscriberCount, 3);

      hub.unsubscribe(a);
      expect(hub.subscriberCount, 1);
      expect(hub.hasRoom('alice', 'X'), isTrue); // b still there
      expect(hub.hasRoom('alice', 'Y'), isFalse); // dropped (empty)
    });

    test('subscriberCount totals across all rooms', () {
      final hub = WsHub();
      expect(hub.subscriberCount, 0);
      hub
        ..subscribe(userId: 'a', pageUlid: '1', channel: _FakeChannel('a1'))
        ..subscribe(userId: 'a', pageUlid: '2', channel: _FakeChannel('a2'))
        ..subscribe(userId: 'b', pageUlid: '1', channel: _FakeChannel('b1'));
      expect(hub.subscriberCount, 3);
    });
  });
}
