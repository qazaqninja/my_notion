/// Verifies the inverse-relation rewriter used by two-way relations
/// (M173). Exercises the pure mirroring helper; the end-to-end
/// propagate-through-the-DB path is covered indirectly by integration
/// tests that re-index after disk writes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/data/repositories/database_repository_impl.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

Frontmatter _fm(Map<String, String> kv) {
  return Frontmatter(entries: [
    for (final e in kv.entries)
      FrontmatterEntry(
        key: e.key,
        rawScalar: e.value,
        type: FrontmatterType.relation,
        value: e.value,
      ),
  ]);
}

String? _read(Frontmatter fm, String key) {
  for (final e in fm.entries) {
    if (e.key == key) return e.rawScalar;
  }
  return null;
}

void main() {
  const ulidA = 'AAAAAAAAAAAAAAAAAAAAAAAAAA';
  const ulidB = 'BBBBBBBBBBBBBBBBBBBBBBBBBB';
  const ulidC = 'CCCCCCCCCCCCCCCCCCCCCCCCCC';

  group('mirrorRelation', () {
    test('adds ULID to an empty entry → [[ULID]] flow list', () {
      final fm = _fm({});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        addUlid: ulidA,
      );
      expect(_read(out, 'customers'), '[[[$ulidA]]]');
    });

    test('appends ULID to existing single value', () {
      final fm = _fm({'customers': '[[$ulidA]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        addUlid: ulidB,
      );
      final raw = _read(out, 'customers')!;
      expect(raw, contains(ulidA));
      expect(raw, contains(ulidB));
      expect(raw, startsWith('['));
      expect(raw, endsWith(']'));
    });

    test('appends ULID to existing flow list', () {
      final fm = _fm({'customers': '[[[$ulidA]], [[$ulidB]]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        addUlid: ulidC,
      );
      final raw = _read(out, 'customers')!;
      expect(raw, contains(ulidA));
      expect(raw, contains(ulidB));
      expect(raw, contains(ulidC));
    });

    test('removing a ULID drops it', () {
      final fm = _fm({'customers': '[[[$ulidA]], [[$ulidB]]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        removeUlid: ulidA,
      );
      final raw = _read(out, 'customers')!;
      expect(raw, isNot(contains(ulidA)));
      expect(raw, contains(ulidB));
    });

    test('removing the last ULID leaves empty bracket', () {
      final fm = _fm({'customers': '[[$ulidA]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        removeUlid: ulidA,
      );
      // empty result: entry retained but raw is ''.
      expect(_read(out, 'customers'), '');
    });

    test('adding a present ULID is idempotent', () {
      final fm = _fm({'customers': '[[$ulidA]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        addUlid: ulidA,
      );
      expect(identical(out, fm), isTrue);
    });

    test('removing an absent ULID is idempotent', () {
      final fm = _fm({'customers': '[[$ulidA]]'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        removeUlid: ulidB,
      );
      expect(identical(out, fm), isTrue);
    });

    test('creates the entry when missing and adding for the first time',
        () {
      final fm = _fm({'title': 'X'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        addUlid: ulidA,
      );
      expect(_read(out, 'customers'), isNotNull);
      expect(_read(out, 'customers')!, contains(ulidA));
    });

    test('does not create an empty entry when removing from a missing key',
        () {
      final fm = _fm({'title': 'X'});
      final out = DatabaseRepositoryImpl.mirrorRelation(
        fm,
        'customers',
        removeUlid: ulidA,
      );
      expect(_read(out, 'customers'), isNull);
    });
  });
}
