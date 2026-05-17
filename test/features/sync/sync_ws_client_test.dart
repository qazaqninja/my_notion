import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/data/sync_ws_client.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// H2.2 — exercises SyncWsClient against a hand-rolled fake
/// WebSocketChannel so we never touch the network. The fake mirrors
/// the half-duplex contract the client uses: inbound via the
/// stream, outbound via the sink.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel({this.openedFor});
  final String? openedFor; // tag for assertions
  final inbound = StreamController<dynamic>.broadcast();
  final outbound = <Object?>[];
  bool closed = false;

  @override
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _Sink(this);

  void simulateMessage(String s) => inbound.add(s);
  void simulateError(Object e) => inbound.addError(e);
  Future<void> simulateServerClose() => inbound.close();

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
    parent.closed = true;
    await parent.inbound.close();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('SyncWsClient (H2.2)', () {
    group('connect()', () {
      test('opens channel and asserts isConnected', () async {
        _FakeChannel? captured;
        String? capturedToken;
        String? capturedUlid;
        String? capturedWsUrl;
        final client = SyncWsClient(
          wsUrl: 'ws://localhost:8080',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) {
            capturedWsUrl = wsUrl;
            capturedToken = token;
            capturedUlid = ulid;
            captured = _FakeChannel(openedFor: ulid);
            return captured!;
          },
        );
        await client.connect(token: 'jwt-test', ulid: 'ULID-1');
        expect(client.isConnected, isTrue);
        expect(client.currentUlid, 'ULID-1');
        expect(capturedToken, 'jwt-test');
        expect(capturedUlid, 'ULID-1');
        expect(capturedWsUrl, 'ws://localhost:8080');
        expect(captured, isNotNull);
        await client.dispose();
      });

      test('inbound messages from channel land on incoming stream',
          () async {
        late _FakeChannel ch;
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              ch = _FakeChannel(),
        );
        final received = <String>[];
        final sub = client.incoming.listen(received.add);
        await client.connect(token: 't', ulid: 'U');
        ch.simulateMessage('hello-from-peer');
        ch.simulateMessage('another-update');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(received, ['hello-from-peer', 'another-update']);
        await sub.cancel();
        await client.dispose();
      });

      test('reconnecting to a different ULID swaps the channel', () async {
        final opened = <String>[];
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) {
            opened.add(ulid);
            return _FakeChannel();
          },
        );
        await client.connect(token: 't', ulid: 'ULID-1');
        await client.connect(token: 't', ulid: 'ULID-2');
        expect(opened, ['ULID-1', 'ULID-2']);
        expect(client.currentUlid, 'ULID-2');
        await client.dispose();
      });
    });

    group('send()', () {
      test('pushes payload onto the channel sink', () async {
        late _FakeChannel ch;
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              ch = _FakeChannel(),
        );
        await client.connect(token: 't', ulid: 'U');
        client.send('outgoing-1');
        client.send('outgoing-2');
        expect(ch.outbound, ['outgoing-1', 'outgoing-2']);
        await client.dispose();
      });

      test('before connect() throws StateError', () {
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              _FakeChannel(),
        );
        expect(() => client.send('nope'), throwsStateError);
      });
    });

    group('close()', () {
      test('flips isConnected back to false', () async {
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              _FakeChannel(),
        );
        await client.connect(token: 't', ulid: 'U');
        expect(client.isConnected, isTrue);
        await client.close();
        expect(client.isConnected, isFalse);
        expect(client.currentUlid, isNull);
        await client.dispose();
      });

      test('server-initiated close drops the channel and clears state',
          () async {
        late _FakeChannel ch;
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              ch = _FakeChannel(),
        );
        await client.connect(token: 't', ulid: 'U');
        expect(client.isConnected, isTrue);
        await ch.simulateServerClose();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(client.isConnected, isFalse);
        expect(client.currentUlid, isNull);
        await client.dispose();
      });
    });

    group('errors', () {
      test('channel error forwards SyncConnectionLostException on incoming',
          () async {
        late _FakeChannel ch;
        final client = SyncWsClient(
          wsUrl: 'ws://x',
          channelFactory: ({
            required String wsUrl,
            required String token,
            required String ulid,
          }) =>
              ch = _FakeChannel(),
        );
        final errors = <Object>[];
        final sub = client.incoming.listen(
          (_) {},
          onError: errors.add,
        );
        await client.connect(token: 't', ulid: 'U');
        ch.simulateError('network-blip');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(errors.single, isA<SyncConnectionLostException>());
        expect(
          (errors.single as SyncConnectionLostException).message,
          contains('network-blip'),
        );
        expect(client.isConnected, isFalse);
        await sub.cancel();
        await client.dispose();
      });
    });
  });
}
