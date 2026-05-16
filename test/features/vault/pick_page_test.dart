import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/domain/usecases/pick_page.dart';

PageRef _p({
  required String ulid,
  String title = '',
  int bodyLen = 0,
  int mtimeMs = 0,
  List<String> tags = const [],
}) =>
    (
      ulid: ulid,
      title: title,
      bodyLen: bodyLen,
      mtimeMs: mtimeMs,
      tags: tags,
    );

void main() {
  group('pickLargest', () {
    test('returns null on empty input', () {
      expect(pickLargest([]), isNull);
    });

    test('picks the page with the highest bodyLen', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 10),
        _p(ulid: 'b', bodyLen: 100),
        _p(ulid: 'c', bodyLen: 50),
      ];
      expect(pickLargest(pages)?.ulid, 'b');
    });

    test('breaks ties by most-recent mtimeMs', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 100, mtimeMs: 1000),
        _p(ulid: 'b', bodyLen: 100, mtimeMs: 2000),
        _p(ulid: 'c', bodyLen: 100, mtimeMs: 1500),
      ];
      expect(pickLargest(pages)?.ulid, 'b');
    });
  });

  group('pickSmallest', () {
    test('returns null on empty input', () {
      expect(pickSmallest([]), isNull);
    });

    test('picks the page with the lowest bodyLen', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 10),
        _p(ulid: 'b', bodyLen: 100),
        _p(ulid: 'c', bodyLen: 1),
      ];
      expect(pickSmallest(pages)?.ulid, 'c');
    });

    test('breaks ties by most-recent mtimeMs (freshest stub wins)', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 0, mtimeMs: 1000),
        _p(ulid: 'b', bodyLen: 0, mtimeMs: 2000),
      ];
      expect(pickSmallest(pages)?.ulid, 'b');
    });
  });

  group('pickLastEdited', () {
    test('returns null on empty input', () {
      expect(pickLastEdited([]), isNull);
    });

    test('picks the highest mtimeMs', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 1000),
        _p(ulid: 'b', mtimeMs: 3000),
        _p(ulid: 'c', mtimeMs: 2000),
      ];
      expect(pickLastEdited(pages)?.ulid, 'b');
    });
  });

  group('filterUntagged', () {
    test('keeps only pages with no tags', () {
      final pages = [
        _p(ulid: 'a', tags: ['work']),
        _p(ulid: 'b'),
        _p(ulid: 'c', tags: ['personal', 'todo']),
        _p(ulid: 'd', tags: []),
      ];
      expect(
        filterUntagged(pages).map((p) => p.ulid).toList(),
        ['b', 'd'],
      );
    });

    test('preserves input order', () {
      final pages = [
        _p(ulid: 'z'),
        _p(ulid: 'a', tags: ['x']),
        _p(ulid: 'y'),
      ];
      expect(
        filterUntagged(pages).map((p) => p.ulid).toList(),
        ['z', 'y'],
      );
    });

    test('returns empty list when every page is tagged', () {
      final pages = [
        _p(ulid: 'a', tags: ['x']),
        _p(ulid: 'b', tags: ['y']),
      ];
      expect(filterUntagged(pages), isEmpty);
    });

    test('returns empty list on empty input', () {
      expect(filterUntagged([]), isEmpty);
    });
  });

  group('filterOrphan', () {
    test('keeps pages absent from both endpoint sets', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b'), _p(ulid: 'c')];
      final rels = [(fromUlid: 'a', toUlid: 'b')];
      // 'a' and 'b' are linked; 'c' is orphan.
      expect(
        filterOrphan(pages, rels).map((p) => p.ulid).toList(),
        ['c'],
      );
    });

    test('a page that only appears as a relation source is NOT orphan', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      final rels = [(fromUlid: 'a', toUlid: 'ghost')];
      // 'a' is a source — counts as linked even if the target is gone.
      // 'b' is the only orphan.
      expect(
        filterOrphan(pages, rels).map((p) => p.ulid).toList(),
        ['b'],
      );
    });

    test('empty relations leaves every page orphan', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      expect(filterOrphan(pages, []).length, 2);
    });

    test('empty pages returns empty', () {
      expect(filterOrphan([], [(fromUlid: 'a', toUlid: 'b')]), isEmpty);
    });
  });

  group('filterStale', () {
    test('keeps pages older than cutoff', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 1000),
        _p(ulid: 'b', mtimeMs: 5000),
        _p(ulid: 'c', mtimeMs: 2000),
      ];
      // Cutoff 3000: 'a' and 'c' are older, 'b' is fresher.
      expect(
        filterStale(pages, 3000).map((p) => p.ulid).toSet(),
        {'a', 'c'},
      );
    });

    test('exactly-equal mtime is NOT stale (strict less-than)', () {
      final pages = [_p(ulid: 'a', mtimeMs: 1000)];
      expect(filterStale(pages, 1000), isEmpty);
    });

    test('empty input returns empty', () {
      expect(filterStale([], 1000), isEmpty);
    });
  });

  group('pickMostLinked', () {
    test('returns null on empty pages', () {
      expect(pickMostLinked([], []), isNull);
    });

    test('returns null when no page has any inbound links', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      expect(pickMostLinked(pages, []), isNull);
    });

    test('returns null when relations exist but target none of the pages',
        () {
      // Relations point to orphan ULIDs not in `pages` — pick should
      // still be null because eligibility is restricted to known pages.
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      final rels = [
        (fromUlid: 'a', toUlid: 'ghost'),
      ];
      expect(pickMostLinked(pages, rels), isNull);
    });

    test('picks the page with the most inbound links', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b'), _p(ulid: 'c')];
      final rels = [
        (fromUlid: 'a', toUlid: 'b'),
        (fromUlid: 'c', toUlid: 'b'),
        (fromUlid: 'a', toUlid: 'c'),
      ];
      final r = pickMostLinked(pages, rels);
      expect(r?.ref.ulid, 'b');
      expect(r?.inboundCount, 2);
    });

    test('breaks ties by most-recent mtimeMs', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 1000),
        _p(ulid: 'b', mtimeMs: 2000),
      ];
      final rels = [
        (fromUlid: 'x', toUlid: 'a'),
        (fromUlid: 'x', toUlid: 'b'),
      ];
      final r = pickMostLinked(pages, rels);
      expect(r?.ref.ulid, 'b'); // higher mtime wins the tie
      expect(r?.inboundCount, 1);
    });
  });
}
