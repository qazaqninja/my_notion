import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/usecases/decode_jwt_sub.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';

/// Build a minimal unsigned JWT-shaped string from a payload Map.
/// The signature segment is just a placeholder — the helper doesn't
/// verify, only extracts.
String _makeToken(Map<String, Object?> payload) {
  String enc(Map<String, Object?> m) {
    final bytes = utf8.encode(jsonEncode(m));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  final header = enc({'alg': 'HS256', 'typ': 'JWT'});
  final body = enc(payload);
  return '$header.$body.fake-signature';
}

void main() {
  group('decodeJwtSub (H4d-iii-d-ii)', () {
    group('happy path', () {
      test('returns the sub claim for a well-formed JWT', () {
        final token =
            _makeToken({'sub': '01HXUSER000000000000000001', 'iat': 0});
        expect(decodeJwtSub(token), '01HXUSER000000000000000001');
      });

      test('handles long base64url without standard padding', () {
        // Payload long enough to force the base64 length to NOT be a
        // multiple of 4 — base64Url.normalize must add the padding
        // back before decode succeeds.
        final token = _makeToken({
          'sub': 'alice',
          'roles': ['owner', 'editor', 'viewer'],
          'iat': 1700000000,
          'exp': 1731536000,
        });
        expect(decodeJwtSub(token), 'alice');
      });
    });

    group('null + empty', () {
      test('returns null on null input', () {
        expect(decodeJwtSub(null), isNull);
      });

      test('returns null on empty string', () {
        expect(decodeJwtSub(''), isNull);
      });
    });

    group('malformed inputs', () {
      test('returns null when segment count is 2', () {
        expect(decodeJwtSub('not.jwt'), isNull);
      });

      test('returns null when segment count is 4', () {
        expect(decodeJwtSub('a.b.c.d'), isNull);
      });

      test('returns null when the middle segment is not base64url',
          () {
        // `!` is not a valid base64url character.
        expect(decodeJwtSub('header.!!!.sig'), isNull);
      });

      test('returns null when payload is valid base64url but not JSON',
          () {
        final notJson = base64Url.encode(utf8.encode('plain text'));
        expect(decodeJwtSub('header.$notJson.sig'), isNull);
      });

      test('returns null when payload is JSON but not an object', () {
        final arr = base64Url.encode(utf8.encode('[1,2,3]'));
        expect(decodeJwtSub('header.$arr.sig'), isNull);
      });

      test('returns null when sub is missing', () {
        final token = _makeToken({'iat': 0});
        expect(decodeJwtSub(token), isNull);
      });

      test('returns null when sub is not a string', () {
        final token = _makeToken({'sub': 42});
        expect(decodeJwtSub(token), isNull);
      });

      test('returns null when sub is an empty string', () {
        final token = _makeToken({'sub': ''});
        expect(decodeJwtSub(token), isNull);
      });
    });
  });

  group('SyncState.userId integration (H4d-iii-d-ii)', () {
    test('derives userId from the token via decodeJwtSub', () {
      final token = _makeToken({'sub': '01HXALICE0000001'});
      final state = SyncState(
        status: SyncStatus.success,
        token: token,
      );
      expect(state.userId, '01HXALICE0000001');
    });

    test('userId is null when unauthed (no token)', () {
      const state = SyncState(status: SyncStatus.initial);
      expect(state.userId, isNull);
    });

    test('userId is null when token is malformed', () {
      const state = SyncState(
        status: SyncStatus.success,
        token: 'not-a-jwt',
      );
      expect(state.userId, isNull);
    });
  });
}
