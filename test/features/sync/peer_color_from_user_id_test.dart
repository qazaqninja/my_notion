import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/usecases/peer_color_from_user_id.dart';

/// H4d-ii — deterministic peer-color helper tests.
void main() {
  group('peerColorFromUserId (H4d-ii)', () {
    group('determinism', () {
      test('same userId returns the same color across calls', () {
        final a = peerColorFromUserId('01HXALICE0001');
        final b = peerColorFromUserId('01HXALICE0001');
        expect(a, b);
      });

      test('every output is a member of peerColorPalette', () {
        // Sample a wide net of distinct inputs to confirm the
        // helper never returns an off-palette value.
        for (final id in [
          'a',
          'alice',
          '01HX0000000000000000000001',
          'bob@example.com',
          'long-user-id-with-dashes-and-numbers-12345',
          '中文用户',
          '',
        ]) {
          expect(peerColorPalette, contains(peerColorFromUserId(id)));
        }
      });

      test('empty input returns the first palette entry', () {
        expect(peerColorFromUserId(''), peerColorPalette.first);
      });
    });

    group('distribution', () {
      test('userIds that differ produce ≥6 distinct colors across 20 samples',
          () {
        final seen = <String>{};
        for (var i = 0; i < 20; i++) {
          seen.add(peerColorFromUserId('user-$i'));
        }
        // Stochastic — we're not asserting all 8 because a small
        // sample with mod-8 hashing can collide. ≥6 distinct out
        // of 20 inputs across 8 buckets is a sane floor; if the
        // helper degenerated to "always return red" this would
        // fail loudly.
        expect(seen.length, greaterThanOrEqualTo(6));
      });
    });

    group('palette shape', () {
      test('palette has exactly 8 entries', () {
        expect(peerColorPalette, hasLength(8));
      });

      test('every palette entry is a #RRGGBB string', () {
        final hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
        for (final c in peerColorPalette) {
          expect(hexPattern.hasMatch(c), isTrue,
              reason: '$c should match #RRGGBB');
        }
      });

      test('palette is unmodifiable', () {
        expect(() => peerColorPalette.add('#000000'),
            throwsUnsupportedError);
      });
    });
  });
}
