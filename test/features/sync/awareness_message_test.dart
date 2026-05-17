import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';

/// H4b — client-side DTO mirror tests. Same shape contract as
/// `backend/test/awareness_message_test.dart` (M1448/M1449) so a
/// payload encoded on one side round-trips on the other.
void main() {
  group('AwarenessMessage (client mirror, H4b)', () {
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
        expect(AwarenessMessage.fromJson(json), msg);
      });

      test('encode → tryDecode reproduces an equal value', () {
        const msg = AwarenessMessage(
          userId: 'u',
          pageUlid: 'p',
          cursorIndex: 0,
          color: '#222',
        );
        expect(AwarenessMessage.tryDecode(msg.encode()), msg);
      });
    });

    group('fromJson validation', () {
      test('rejects wrong kind tag', () {
        expect(
          () => AwarenessMessage.fromJson(const <String, Object?>{
            'kind': 'update',
            'userId': 'x',
            'pageUlid': 'y',
            'cursorIndex': 0,
            'color': '#000',
          }),
          throwsFormatException,
        );
      });

      test('rejects missing field', () {
        expect(
          () => AwarenessMessage.fromJson(const <String, Object?>{
            'kind': 'awareness',
            'userId': 'x',
            'pageUlid': 'y',
            'color': '#000',
          }),
          throwsFormatException,
        );
      });

      test('rejects non-int cursorIndex', () {
        expect(
          () => AwarenessMessage.fromJson(const <String, Object?>{
            'kind': 'awareness',
            'userId': 'x',
            'pageUlid': 'y',
            'cursorIndex': '42',
            'color': '#000',
          }),
          throwsFormatException,
        );
      });
    });

    group('tryDecode fall-through', () {
      test('returns null on malformed JSON',
          () => expect(AwarenessMessage.tryDecode('not json'), isNull));

      test('returns null on non-object JSON',
          () => expect(AwarenessMessage.tryDecode('[1,2]'), isNull));

      test('returns null on kind mismatch (CRDT update path)', () {
        expect(
          AwarenessMessage.tryDecode('{"kind":"update","payload":"abc"}'),
          isNull,
        );
      });
    });

    group('equality', () {
      test('Equatable: same fields → equal', () {
        const a = AwarenessMessage(
            userId: 'u', pageUlid: 'p', cursorIndex: 1, color: '#f00');
        const b = AwarenessMessage(
            userId: 'u', pageUlid: 'p', cursorIndex: 1, color: '#f00');
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('any of the 4 field deltas breaks equality', () {
        const base = AwarenessMessage(
            userId: 'u', pageUlid: 'p', cursorIndex: 1, color: '#f00');
        expect(
            base ==
                const AwarenessMessage(
                    userId: 'u2',
                    pageUlid: 'p',
                    cursorIndex: 1,
                    color: '#f00'),
            isFalse);
        expect(
            base ==
                const AwarenessMessage(
                    userId: 'u',
                    pageUlid: 'p2',
                    cursorIndex: 1,
                    color: '#f00'),
            isFalse);
        expect(
            base ==
                const AwarenessMessage(
                    userId: 'u',
                    pageUlid: 'p',
                    cursorIndex: 2,
                    color: '#f00'),
            isFalse);
        expect(
            base ==
                const AwarenessMessage(
                    userId: 'u',
                    pageUlid: 'p',
                    cursorIndex: 1,
                    color: '#00f'),
            isFalse);
      });
    });
  });
}
