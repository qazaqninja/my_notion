import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/forms/domain/usecases/list_form_bearing_pages.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';
import 'package:my_notion/features/vault/domain/entities/page.dart' as pg;

pg.Page _pg({
  required String ulid,
  required String title,
  required String relativePath,
  Map<String, Object?> fm = const {},
}) {
  // Project a {key: value} map into an ordered list of
  // FrontmatterEntry — rawScalar / type aren't load-bearing for
  // this usecase's read path (it just looks up frontmatter.get).
  final entries = <FrontmatterEntry>[];
  fm.forEach((k, v) {
    entries.add(FrontmatterEntry(
      key: k,
      rawScalar: '$v',
      type: FrontmatterType.text,
      value: v,
    ));
  });
  return pg.Page(
    ulid: ulid,
    relativePath: relativePath,
    title: title,
    frontmatter: Frontmatter(entries: entries),
    body: '',
  );
}

void main() {
  // M1409 — slice milestone tag lives in the file-level history
  // comments above, not in the group name (TS-04 info).
  group('listFormBearingPages', () {
    test('empty input → empty output', () {
      expect(listFormBearingPages(const []), isEmpty);
    });

    test('skips pages with no `forms:` key', () {
      final pages = [
        _pg(ulid: 'A', title: 'Notes', relativePath: 'Notes.md'),
        _pg(
          ulid: 'B',
          title: 'Settings',
          relativePath: 'Settings.md',
          fm: {'title': 'Settings'},
        ),
      ];
      expect(listFormBearingPages(pages), isEmpty);
    });

    test('skips pages with `forms:` set to a blank value', () {
      final pages = [
        _pg(ulid: 'A', title: 'Empty forms', relativePath: 'A.md',
            fm: {'forms': ''}),
        _pg(ulid: 'B', title: 'Whitespace', relativePath: 'B.md',
            fm: {'forms': '   '}),
      ];
      expect(listFormBearingPages(pages), isEmpty);
    });

    test('includes a page with `forms: true`', () {
      final pages = [
        _pg(
          ulid: 'A',
          title: 'Customer feedback',
          relativePath: 'Inbox/Customer feedback.md',
          fm: {'forms': true},
        ),
      ];
      final result = listFormBearingPages(pages);
      expect(result, hasLength(1));
      expect(result.single.ulid, 'A');
      expect(result.single.title, 'Customer feedback');
      expect(result.single.relativePath, 'Inbox/Customer feedback.md');
      expect(result.single.formsRef, 'true');
    });

    test('includes a page with `forms: <db-ref>` and preserves the ref', () {
      final pages = [
        _pg(
          ulid: 'A',
          title: 'Bug reports',
          relativePath: 'Operations/Bug reports.md',
          fm: {'forms': 'Operations/Bugs.database.yaml'},
        ),
      ];
      final result = listFormBearingPages(pages);
      expect(result.single.formsRef, 'Operations/Bugs.database.yaml');
    });

    test('returns pages sorted alphabetically by title (predictable UX)', () {
      final pages = [
        _pg(ulid: 'A', title: 'Zeta', relativePath: 'Z.md',
            fm: {'forms': true}),
        _pg(ulid: 'B', title: 'Alpha', relativePath: 'A.md',
            fm: {'forms': true}),
        _pg(ulid: 'C', title: 'Mike', relativePath: 'M.md',
            fm: {'forms': true}),
      ];
      final titles = listFormBearingPages(pages).map((p) => p.title).toList();
      expect(titles, ['Alpha', 'Mike', 'Zeta']);
    });

    test('alphabetical sort is case-insensitive', () {
      final pages = [
        _pg(ulid: 'A', title: 'bravo', relativePath: 'b.md',
            fm: {'forms': true}),
        _pg(ulid: 'B', title: 'Alpha', relativePath: 'a.md',
            fm: {'forms': true}),
        _pg(ulid: 'C', title: 'CHARLIE', relativePath: 'c.md',
            fm: {'forms': true}),
      ];
      final titles = listFormBearingPages(pages).map((p) => p.title).toList();
      expect(titles, ['Alpha', 'bravo', 'CHARLIE']);
    });

    test('mixed input — only form-bearing pages included, others dropped',
        () {
      final pages = [
        _pg(ulid: 'A', title: 'Plain', relativePath: 'p.md'),
        _pg(ulid: 'B', title: 'Survey', relativePath: 's.md',
            fm: {'forms': true}),
        _pg(ulid: 'C', title: 'Empty', relativePath: 'e.md',
            fm: {'forms': ''}),
        _pg(ulid: 'D', title: 'Bug report form',
            relativePath: 'b.md', fm: {'forms': 'Bugs.yaml'}),
      ];
      final result = listFormBearingPages(pages);
      expect(result.map((p) => p.ulid), ['D', 'B']);
    });
  });
}
