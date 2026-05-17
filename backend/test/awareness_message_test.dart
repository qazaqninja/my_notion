import 'package:backend/sync/awareness_message.dart';
import 'package:test/test.dart';

/// H4a — wire DTO tests for [AwarenessMessage]. Covers the
/// round-trip contract, the kind-discriminator gate, the missing-
/// field guard, and the tryDecode fall-through that the H4b
/// dispatcher will rely on.
void main() {
  group('AwarenessMessage', () {
    group('toJson + fromJson round-trip', () {
      test('preserves all fields verbatim', () {
        const msg = AwarenessMessage(
          userId: '01HXUSER0001',
          pageUlid: '01HXPAGE0001',
          cursorIndex: 42,
          color: '#FF5722',
        );
        final json = msg.toJson();
        expect(json['kind'], 'awareness');
        expect(json['userId'], '01HXUSER0001');
        expect(json['pageUlid'], '01HXPAGE0001');
        expect(json['cursorIndex'], 42);
        expect(json['color'], '#FF5722');
        final restored = AwarenessMessage.fromJson(json);
        expect(restored, msg);
      });

      test('encode → tryDecode reproduces an equal value', () {
        const msg = AwarenessMessage(
          userId: '01HXUSER0002',
          pageUlid: '01HXPAGE0002',
          cursorIndex: 0,
          color: '#222222',
        );
        final raw = msg.encode();
        final decoded = AwarenessMessage.tryDecode(raw);
        expect(decoded, msg);
      });
    });

    group('fromJson validation', () {
      test('rejects a payload with the wrong kind tag', () {
        expect(
          () => AwarenessMessage.fromJson(<String, Object?>{
            'kind': 'update',
            'userId': 'x',
            'pageUlid': 'y',
            'cursorIndex': 0,
            'color': '#000',
          }),
          throwsFormatException,
        );
      });

      test('rejects when the kind tag is missing', () {
        expect(
          () => AwarenessMessage.fromJson(<String, Object?>{
            'userId': 'x',
            'pageUlid': 'y',
            'cursorIndex': 0,
            'color': '#000',
          }),
          throwsFormatException,
        );
      });

      test('rejects when a required field is missing', () {
        expect(
          () => AwarenessMessage.fromJson(<String, Object?>{
            'kind': 'awareness',
            'userId': 'x',
            'pageUlid': 'y',
            // cursorIndex missing
            'color': '#000',
          }),
          throwsFormatException,
        );
      });

      test('rejects when cursorIndex is a non-int', () {
        expect(
          () => AwarenessMessage.fromJson(<String, Object?>{
            'kind': 'awareness',
            'userId': 'x',
            'pageUlid': 'y',
            'cursorIndex': '42', // string, not int
            'color': '#000',
          }),
          throwsFormatException,
        );
      });
    });

    group('tryDecode fall-through', () {
      test('returns null on completely malformed JSON', () {
        expect(AwarenessMessage.tryDecode('not json at all'), isNull);
      });

      test('returns null when JSON is not an object', () {
        expect(AwarenessMessage.tryDecode('[1, 2, 3]'), isNull);
      });

      test('returns null when kind tag mismatches', () {
        // Simulates a CRDT update message arriving on the same
        // channel — H4b's dispatcher should fall through.
        expect(
          AwarenessMessage.tryDecode(
              '{"kind":"update","payload":"abc"}'),
          isNull,
        );
      });

      test('returns null when JSON is valid but required fields missing',
          () {
        expect(
          AwarenessMessage.tryDecode('{"kind":"awareness"}'),
          isNull,
        );
      });
    });

    group('equality + hashCode', () {
      test('two messages with identical fields are equal', () {
        const a = AwarenessMessage(
          userId: 'u',
          pageUlid: 'p',
          cursorIndex: 10,
          color: '#f00',
        );
        const b = AwarenessMessage(
          userId: 'u',
          pageUlid: 'p',
          cursorIndex: 10,
          color: '#f00',
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('two messages differing in any field are NOT equal', () {
        const base = AwarenessMessage(
          userId: 'u',
          pageUlid: 'p',
          cursorIndex: 10,
          color: '#f00',
        );
        // userId differs
        expect(
          base ==
              const AwarenessMessage(
                userId: 'u2',
                pageUlid: 'p',
                cursorIndex: 10,
                color: '#f00',
              ),
          isFalse,
        );
        // pageUlid differs (M1449 TS-04 INFO fix — coverage gap).
        expect(
          base ==
              const AwarenessMessage(
                userId: 'u',
                pageUlid: 'p2',
                cursorIndex: 10,
                color: '#f00',
              ),
          isFalse,
        );
        // cursorIndex differs
        expect(
          base ==
              const AwarenessMessage(
                userId: 'u',
                pageUlid: 'p',
                cursorIndex: 11,
                color: '#f00',
              ),
          isFalse,
        );
        // color differs (M1449 TS-04 INFO fix — coverage gap).
        expect(
          base ==
              const AwarenessMessage(
                userId: 'u',
                pageUlid: 'p',
                cursorIndex: 10,
                color: '#00f',
              ),
          isFalse,
        );
      });
    });
  });
}
