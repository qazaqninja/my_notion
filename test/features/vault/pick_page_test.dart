import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/domain/usecases/pick_page.dart';

PageRef _p({
  required String ulid,
  String title = '',
  int bodyLen = 0,
  int mtimeMs = 0,
  List<String> tags = const [],
  String bodyText = '',
  String relativePath = '',
}) =>
    (
      ulid: ulid,
      title: title,
      bodyLen: bodyLen,
      mtimeMs: mtimeMs,
      tags: tags,
      bodyText: bodyText,
      relativePath: relativePath,
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

  group('pickOldest', () {
    test('returns null on empty input', () {
      expect(pickOldest([]), isNull);
    });

    test('picks the lowest mtimeMs', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 3000),
        _p(ulid: 'b', mtimeMs: 1000),
        _p(ulid: 'c', mtimeMs: 2000),
      ];
      expect(pickOldest(pages)?.ulid, 'b');
    });

    test('single-page input returns that page', () {
      final pages = [_p(ulid: 'a', mtimeMs: 9999)];
      expect(pickOldest(pages)?.ulid, 'a');
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

  group('topByBodyLen', () {
    test('returns top N sorted by bodyLen descending', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 10),
        _p(ulid: 'b', bodyLen: 100),
        _p(ulid: 'c', bodyLen: 50),
        _p(ulid: 'd', bodyLen: 5),
      ];
      expect(
        topByBodyLen(pages, 2).map((p) => p.ulid).toList(),
        ['b', 'c'],
      );
    });

    test('ties broken by most-recent mtime', () {
      final pages = [
        _p(ulid: 'a', bodyLen: 100, mtimeMs: 1000),
        _p(ulid: 'b', bodyLen: 100, mtimeMs: 3000),
        _p(ulid: 'c', bodyLen: 100, mtimeMs: 2000),
      ];
      expect(
        topByBodyLen(pages, 3).map((p) => p.ulid).toList(),
        ['b', 'c', 'a'],
      );
    });

    test('n=0 returns empty', () {
      expect(topByBodyLen([_p(ulid: 'a')], 0), isEmpty);
    });

    test('negative n returns empty (defensive)', () {
      expect(topByBodyLen([_p(ulid: 'a')], -5), isEmpty);
    });

    test('n larger than page count returns every page', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      expect(topByBodyLen(pages, 99).length, 2);
    });
  });

  group('topByMtime', () {
    test('returns top N most-recently-edited descending', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 1000),
        _p(ulid: 'b', mtimeMs: 3000),
        _p(ulid: 'c', mtimeMs: 2000),
      ];
      expect(
        topByMtime(pages, 2).map((p) => p.ulid).toList(),
        ['b', 'c'],
      );
    });

    test('mtimeMs ties broken by ULID lex for determinism', () {
      final pages = [
        _p(ulid: 'z', mtimeMs: 1000),
        _p(ulid: 'a', mtimeMs: 1000),
      ];
      // 'a' < 'z' lex, so 'a' wins the tie.
      expect(
        topByMtime(pages, 2).map((p) => p.ulid).toList(),
        ['a', 'z'],
      );
    });

    test('n=0 returns empty', () {
      expect(topByMtime([_p(ulid: 'a')], 0), isEmpty);
    });
  });

  group('topByBacklinkCount', () {
    test('returns top N by inbound count descending', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b'), _p(ulid: 'c')];
      final rels = [
        (fromUlid: 'a', toUlid: 'b'),
        (fromUlid: 'c', toUlid: 'b'),
        (fromUlid: 'a', toUlid: 'c'),
      ];
      // b has 2 inbound, c has 1, a has 0 → top 2 is [b, c].
      expect(
        topByBacklinkCount(pages, rels, 2).map((p) => p.ulid).toList(),
        ['b', 'c'],
      );
    });

    test('pages with zero inbound links are excluded', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b')];
      final rels = [(fromUlid: 'a', toUlid: 'b')];
      expect(topByBacklinkCount(pages, rels, 99).length, 1);
    });

    test('ties broken by most-recent mtime', () {
      final pages = [
        _p(ulid: 'a', mtimeMs: 1000),
        _p(ulid: 'b', mtimeMs: 2000),
      ];
      final rels = [
        (fromUlid: 'x', toUlid: 'a'),
        (fromUlid: 'x', toUlid: 'b'),
      ];
      expect(
        topByBacklinkCount(pages, rels, 2).map((p) => p.ulid).toList(),
        ['b', 'a'],
      );
    });

    test('empty relations returns empty', () {
      expect(topByBacklinkCount([_p(ulid: 'a')], [], 10), isEmpty);
    });

    test('n=0 returns empty', () {
      final pages = [_p(ulid: 'a')];
      final rels = [(fromUlid: 'x', toUlid: 'a')];
      expect(topByBacklinkCount(pages, rels, 0), isEmpty);
    });
  });

  group('pickRandom', () {
    test('returns null on empty input', () {
      expect(pickRandom([], math.Random(42)), isNull);
    });

    test('returns the only element of a single-page list', () {
      final pages = [_p(ulid: 'a')];
      expect(pickRandom(pages, math.Random(42))?.ulid, 'a');
    });

    test('same seed yields the same pick (deterministic)', () {
      final pages = [_p(ulid: 'a'), _p(ulid: 'b'), _p(ulid: 'c'), _p(ulid: 'd')];
      final p1 = pickRandom(pages, math.Random(123));
      final p2 = pickRandom(pages, math.Random(123));
      expect(p1?.ulid, p2?.ulid);
    });

    test('different seeds can produce different picks', () {
      final pages = List.generate(10, (i) => _p(ulid: 'p$i'));
      // With 10 candidates and these two seeds the picks ARE different,
      // which exercises the path that doesn't always return [0].
      final p1 = pickRandom(pages, math.Random(1))?.ulid;
      final p2 = pickRandom(pages, math.Random(999_999))?.ulid;
      expect(p1, isNot(equals(p2)));
    });

    test('pick is always inside the input list', () {
      final pages = List.generate(5, (i) => _p(ulid: 'p$i'));
      for (var seed = 0; seed < 20; seed++) {
        final pick = pickRandom(pages, math.Random(seed))!;
        expect(pages.contains(pick), isTrue);
      }
    });
  });

  group('countByTopFolder', () {
    test('sums pages per top-level folder', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Operations/Acme.md'),
        _p(ulid: 'b', relativePath: 'Operations/Globex.md'),
        _p(ulid: 'c', relativePath: 'Meetings/Q1.md'),
        _p(ulid: 'd', relativePath: 'Inbox.md'),
      ];
      final f = countByTopFolder(pages);
      expect(f['Operations'], 2);
      expect(f['Meetings'], 1);
      expect(f['(root)'], 1);
    });

    test('deeply nested paths still bucket under top folder', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Operations/Sub/Deep/X.md'),
        _p(ulid: 'b', relativePath: 'Operations/Sub/Y.md'),
      ];
      final f = countByTopFolder(pages);
      expect(f['Operations'], 2);
      expect(f.length, 1);
    });

    test('every page at root bucketed under (root)', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Inbox.md'),
        _p(ulid: 'b', relativePath: 'TODO.md'),
      ];
      final f = countByTopFolder(pages);
      expect(f['(root)'], 2);
      expect(f.length, 1);
    });

    test('empty input returns empty map', () {
      expect(countByTopFolder([]), isEmpty);
    });
  });

  group('filterByFolder', () {
    test('keeps pages whose path starts with `folder/`', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Operations/Acme.md'),
        _p(ulid: 'b', relativePath: 'Operations/Sub/X.md'),
        _p(ulid: 'c', relativePath: 'Inbox.md'),
      ];
      expect(
        filterByFolder(pages, 'Operations').map((p) => p.ulid).toSet(),
        {'a', 'b'},
      );
    });

    test('does NOT match path components in the middle', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Inbox/Operations.md'),
      ];
      expect(filterByFolder(pages, 'Operations'), isEmpty);
    });

    test('top-level same-name page is NOT in the folder', () {
      // 'Operations.md' is a sibling file, not inside 'Operations/'.
      final pages = [_p(ulid: 'a', relativePath: 'Operations.md')];
      expect(filterByFolder(pages, 'Operations'), isEmpty);
    });

    test('trailing slash on input is normalized away', () {
      final pages = [_p(ulid: 'a', relativePath: 'Operations/Foo.md')];
      expect(filterByFolder(pages, 'Operations/').length, 1);
      expect(filterByFolder(pages, 'Operations///').length, 1);
    });

    test('empty folder returns empty', () {
      final pages = [_p(ulid: 'a', relativePath: 'Foo.md')];
      expect(filterByFolder(pages, ''), isEmpty);
      expect(filterByFolder(pages, '   '), isEmpty);
    });

    test('case-sensitive match (vault folders preserve case)', () {
      final pages = [
        _p(ulid: 'a', relativePath: 'Operations/x.md'),
      ];
      expect(filterByFolder(pages, 'operations'), isEmpty);
    });
  });

  group('filterTitleStartsWith', () {
    test('keeps pages whose title begins with the prefix', () {
      final pages = [
        _p(ulid: 'a', title: 'Project: alpha'),
        _p(ulid: 'b', title: 'Other'),
        _p(ulid: 'c', title: 'Project: beta'),
      ];
      expect(
        filterTitleStartsWith(pages, 'Project:').map((p) => p.ulid).toSet(),
        {'a', 'c'},
      );
    });

    test('case-insensitive', () {
      final pages = [
        _p(ulid: 'a', title: 'PROJECT: foo'),
        _p(ulid: 'b', title: 'project: bar'),
      ];
      expect(filterTitleStartsWith(pages, 'project:').length, 2);
    });

    test('trims surrounding whitespace on the prefix', () {
      final pages = [_p(ulid: 'a', title: 'Foo')];
      expect(filterTitleStartsWith(pages, '  foo').length, 1);
    });

    test('empty prefix returns empty (no wildcard)', () {
      final pages = [_p(ulid: 'a', title: 'anything')];
      expect(filterTitleStartsWith(pages, ''), isEmpty);
      expect(filterTitleStartsWith(pages, '   '), isEmpty);
    });

    test('substring match in the middle does NOT count', () {
      final pages = [_p(ulid: 'a', title: 'My Project: foo')];
      expect(filterTitleStartsWith(pages, 'Project'), isEmpty);
    });

    test('empty pages returns empty', () {
      expect(filterTitleStartsWith([], 'foo'), isEmpty);
    });
  });

  group('filterTitleContains', () {
    test('matches substrings case-insensitively', () {
      final pages = [
        _p(ulid: 'a', title: 'Project Plan'),
        _p(ulid: 'b', title: 'Random Notes'),
        _p(ulid: 'c', title: 'project retrospective'),
      ];
      expect(
        filterTitleContains(pages, 'proj').map((p) => p.ulid).toSet(),
        {'a', 'c'},
      );
    });

    test('preserves input order', () {
      final pages = [
        _p(ulid: 'z', title: 'Project A'),
        _p(ulid: 'a', title: 'Other'),
        _p(ulid: 'y', title: 'Project B'),
      ];
      expect(
        filterTitleContains(pages, 'project').map((p) => p.ulid).toList(),
        ['z', 'y'],
      );
    });

    test('empty query returns empty (no wildcard)', () {
      final pages = [_p(ulid: 'a', title: 'anything')];
      expect(filterTitleContains(pages, ''), isEmpty);
      expect(filterTitleContains(pages, '   '), isEmpty);
    });

    test('no match returns empty', () {
      final pages = [_p(ulid: 'a', title: 'Foo')];
      expect(filterTitleContains(pages, 'bar'), isEmpty);
    });

    test('empty input returns empty', () {
      expect(filterTitleContains([], 'anything'), isEmpty);
    });
  });

  group('pickByTitle', () {
    test('case-insensitive match returns the first found', () {
      final pages = [
        _p(ulid: 'a', title: 'Project'),
        _p(ulid: 'b', title: 'project'),
      ];
      expect(pickByTitle(pages, 'PROJECT')?.ulid, 'a');
    });

    test('case-sensitive=true requires exact case', () {
      final pages = [
        _p(ulid: 'a', title: 'Project'),
        _p(ulid: 'b', title: 'project'),
      ];
      expect(pickByTitle(pages, 'project', caseSensitive: true)?.ulid, 'b');
      expect(
        pickByTitle(pages, 'PROJECT', caseSensitive: true),
        isNull,
      );
    });

    test('trims whitespace on both sides before comparing', () {
      final pages = [_p(ulid: 'a', title: '  Project  ')];
      expect(pickByTitle(pages, 'Project')?.ulid, 'a');
      expect(pickByTitle(pages, '  Project  ')?.ulid, 'a');
    });

    test('empty query returns null (no wildcard)', () {
      final pages = [_p(ulid: 'a', title: 'anything')];
      expect(pickByTitle(pages, ''), isNull);
      expect(pickByTitle(pages, '   '), isNull);
    });

    test('no match returns null', () {
      final pages = [_p(ulid: 'a', title: 'Foo')];
      expect(pickByTitle(pages, 'Bar'), isNull);
    });

    test('empty pages returns null', () {
      expect(pickByTitle([], 'anything'), isNull);
    });
  });

  group('pickByUlid', () {
    test('returns the matching page', () {
      final pages = [
        _p(ulid: 'a', title: 'Alpha'),
        _p(ulid: 'b', title: 'Beta'),
      ];
      expect(pickByUlid(pages, 'b')?.title, 'Beta');
    });

    test('returns null when no match', () {
      final pages = [_p(ulid: 'a')];
      expect(pickByUlid(pages, 'ghost'), isNull);
    });

    test('returns null on empty input', () {
      expect(pickByUlid([], 'a'), isNull);
    });

    test('returns the first match if duplicates exist (defensive)', () {
      final pages = [
        _p(ulid: 'a', title: 'First'),
        _p(ulid: 'a', title: 'Second'),
      ];
      // ULID collisions shouldn't happen in production but the
      // function shouldn't blow up if they do — first wins.
      expect(pickByUlid(pages, 'a')?.title, 'First');
    });
  });

  group('countTagFrequency', () {
    test('sums occurrences across pages', () {
      final pages = [
        _p(ulid: 'a', tags: ['work', 'urgent']),
        _p(ulid: 'b', tags: ['work', 'personal']),
        _p(ulid: 'c', tags: ['urgent']),
      ];
      final f = countTagFrequency(pages);
      expect(f['work'], 2);
      expect(f['urgent'], 2);
      expect(f['personal'], 1);
    });

    test('preserves tag case (callers fold if they need)', () {
      final pages = [
        _p(ulid: 'a', tags: ['Work']),
        _p(ulid: 'b', tags: ['work']),
      ];
      final f = countTagFrequency(pages);
      expect(f['Work'], 1);
      expect(f['work'], 1);
    });

    test('skips empty / whitespace-only tag entries', () {
      final pages = [
        _p(ulid: 'a', tags: ['  ', '']),
        _p(ulid: 'b', tags: ['real']),
      ];
      final f = countTagFrequency(pages);
      expect(f.containsKey(''), isFalse);
      expect(f.containsKey('  '), isFalse);
      expect(f['real'], 1);
    });

    test('trims surrounding whitespace before counting', () {
      // Both pages have the same logical tag after trim; the count
      // collapses to a single key.
      final pages = [
        _p(ulid: 'a', tags: ['  work  ']),
        _p(ulid: 'b', tags: ['work']),
      ];
      final f = countTagFrequency(pages);
      expect(f['work'], 2);
    });

    test('empty input returns empty map', () {
      expect(countTagFrequency([]), isEmpty);
    });
  });

  group('filterByTag', () {
    test('keeps pages whose tag list contains the query', () {
      final pages = [
        _p(ulid: 'a', tags: ['work', 'urgent']),
        _p(ulid: 'b', tags: ['personal']),
        _p(ulid: 'c', tags: ['work']),
      ];
      expect(
        filterByTag(pages, 'work').map((p) => p.ulid).toSet(),
        {'a', 'c'},
      );
    });

    test('matches case-insensitively', () {
      final pages = [
        _p(ulid: 'a', tags: ['Work']),
        _p(ulid: 'b', tags: ['WORK']),
      ];
      expect(filterByTag(pages, 'work').length, 2);
    });

    test('trims whitespace on both sides of the comparison', () {
      final pages = [
        _p(ulid: 'a', tags: ['  work  ']),
      ];
      expect(filterByTag(pages, '  Work').length, 1);
    });

    test('empty query returns empty (no wildcard semantics)', () {
      final pages = [_p(ulid: 'a', tags: ['x'])];
      expect(filterByTag(pages, ''), isEmpty);
      expect(filterByTag(pages, '   '), isEmpty);
    });

    test('empty pages returns empty', () {
      expect(filterByTag([], 'work'), isEmpty);
    });

    test('no match returns empty', () {
      final pages = [_p(ulid: 'a', tags: ['x'])];
      expect(filterByTag(pages, 'y'), isEmpty);
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

  group('filterEmpty', () {
    test('keeps pages whose body trims to empty', () {
      final pages = [
        _p(ulid: 'a', bodyText: 'real content'),
        _p(ulid: 'b'),
        _p(ulid: 'c', bodyText: '   \n  \n'),
      ];
      expect(
        filterEmpty(pages).map((p) => p.ulid).toSet(),
        {'b', 'c'},
      );
    });

    test('a body that is only newlines counts as empty', () {
      expect(filterEmpty([_p(ulid: 'a', bodyText: '\n\n\n')]).length, 1);
    });

    test('empty input returns empty', () {
      expect(filterEmpty([]), isEmpty);
    });
  });

  group('filterPagesWithOpenTodos', () {
    test('keeps pages with at least one - [ ] marker', () {
      final pages = [
        _p(ulid: 'a', bodyText: 'no todos here'),
        _p(ulid: 'b', bodyText: 'preamble\n- [ ] todo\n'),
        _p(ulid: 'c', bodyText: '* [ ] also todo\n'),
        _p(ulid: 'd', bodyText: '+ [ ] plus form\n'),
      ];
      expect(
        filterPagesWithOpenTodos(pages).map((p) => p.ulid).toSet(),
        {'b', 'c', 'd'},
      );
    });

    test('checked todos do NOT count as open', () {
      final pages = [
        _p(ulid: 'a', bodyText: '- [x] done\n'),
      ];
      expect(filterPagesWithOpenTodos(pages), isEmpty);
    });

    test('indented unchecked todos still count', () {
      final pages = [_p(ulid: 'a', bodyText: '   - [ ] indented\n')];
      expect(filterPagesWithOpenTodos(pages).length, 1);
    });

    test('empty input returns empty', () {
      expect(filterPagesWithOpenTodos([]), isEmpty);
    });
  });

  group('filterDuplicateTitles', () {
    test('case-insensitive grouping surfaces both sides of a duplicate', () {
      final pages = [
        _p(ulid: 'a', title: 'Project'),
        _p(ulid: 'b', title: 'project'),
        _p(ulid: 'c', title: 'Other'),
      ];
      expect(
        filterDuplicateTitles(pages).map((p) => p.ulid).toSet(),
        {'a', 'b'},
      );
    });

    test('within a bucket, freshest mtime comes first', () {
      final pages = [
        _p(ulid: 'a', title: 'Note', mtimeMs: 1000),
        _p(ulid: 'b', title: 'note', mtimeMs: 3000),
        _p(ulid: 'c', title: 'NOTE', mtimeMs: 2000),
      ];
      expect(
        filterDuplicateTitles(pages).map((p) => p.ulid).toList(),
        ['b', 'c', 'a'],
      );
    });

    test('empty-title pages are skipped (no double-report)', () {
      final pages = [
        _p(ulid: 'a'),
        _p(ulid: 'b'),
      ];
      expect(filterDuplicateTitles(pages), isEmpty);
    });

    test('single occurrence of each title returns empty', () {
      final pages = [
        _p(ulid: 'a', title: 'foo'),
        _p(ulid: 'b', title: 'bar'),
      ];
      expect(filterDuplicateTitles(pages), isEmpty);
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
