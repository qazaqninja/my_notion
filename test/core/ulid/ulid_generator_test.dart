import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';

/// Tests for `UlidGenerator`, the thin wrapper around `package:ulid`
/// that enforces uppercase Crockford output.
///
/// The wrapper exists because `package:ulid` emits lowercase, which
/// collides with the inline-wikilink regex `[0-9A-HJKMNP-TV-Z]{26}`
/// and the upper-case IDs that ship in fixture vaults. Forcing
/// uppercase keeps newly created pages addressable from wikilinks
/// and matches the on-disk convention.
///
/// Mirrors the lib-tree layout (FS-04 / TS-01).
void main() {
  group('UlidGenerator — shape', () {
    test('generate() returns exactly 26 characters', () {
      const gen = UlidGenerator();
      expect(gen.generate().length, 26);
    });

    test('output uses uppercase Crockford alphabet', () {
      // Crockford base32 excludes I, L, O, U to avoid visual
      // confusion. The valid character class is
      // `[0-9A-HJKMNP-TV-Z]`.
      const gen = UlidGenerator();
      final id = gen.generate();
      final re = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$');
      expect(re.hasMatch(id), true,
          reason: 'Generated ULID `$id` is not pure '
              'uppercase Crockford base32.',);
    });

    test('output has no lowercase letters', () {
      const gen = UlidGenerator();
      final id = gen.generate();
      // The wrapper's whole job is enforcing uppercase. Bug
      // here would mean ULIDs collide with wikilink lookup.
      expect(id, equals(id.toUpperCase()));
    });
  });

  group('UlidGenerator — uniqueness', () {
    test('two consecutive generate() calls return distinct IDs', () {
      const gen = UlidGenerator();
      final a = gen.generate();
      final b = gen.generate();
      expect(a, isNot(equals(b)));
    });

    test('100 consecutive calls all return unique IDs', () {
      // ULID's timestamp prefix + random suffix should keep
      // collisions astronomically unlikely. 100 fast calls is
      // a sanity check that the random source is non-degenerate.
      const gen = UlidGenerator();
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(gen.generate());
      }
      expect(ids.length, 100);
    });
  });

  group('UlidGenerator — ordering', () {
    test('two IDs from the same millisecond share a timestamp prefix', () {
      // ULIDs are timestamp-ordered: the first 10 chars encode
      // milliseconds-since-epoch. Two IDs generated quickly
      // should share at least the first ~9 chars.
      const gen = UlidGenerator();
      final a = gen.generate();
      final b = gen.generate();
      // Looser check: at least the first 8 chars match. The
      // 10th char rolls over every ~33ms, the 9th every ~1s,
      // so 8-char match is robust under typical scheduler load.
      expect(a.substring(0, 8), equals(b.substring(0, 8)));
    });
  });
}
