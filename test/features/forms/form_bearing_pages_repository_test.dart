import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/features/forms/data/repositories/form_bearing_pages_repository.dart';

void main() {
  group('FormBearingPagesRepository', () {
    late QuillDatabase db;
    late FormBearingPagesRepository repo;

    setUp(() {
      db = QuillDatabase.forTesting(NativeDatabase.memory());
      repo = FormBearingPagesRepository(db);
      addTearDown(() async {
        await db.close();
      });
    });

    Future<void> seed({
      required String ulid,
      required String title,
      required String relativePath,
      Map<String, Object?>? frontmatter,
    }) async {
      await db.into(db.pages).insert(PagesCompanion.insert(
            ulid: ulid,
            relativePath: relativePath,
            title: title,
            frontmatterJson:
                frontmatter == null ? '{}' : jsonEncode(frontmatter),
            bodyText: '',
            mtimeMs: const Value(0),
          ));
    }

    test('empty database → empty result', () async {
      expect(await repo.loadAll(), isEmpty);
    });

    test('pages with no `forms:` key are skipped', () async {
      await seed(ulid: '01HX0V0000000000000000000A', title: 'Notes', relativePath: 'Notes.md');
      await seed(
        ulid: '01HX0V0000000000000000000B',
        title: 'Settings',
        relativePath: 'Settings.md',
        frontmatter: {'title': 'Settings'},
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('pages with blank `forms:` are skipped', () async {
      await seed(
        ulid: '01HX0V0000000000000000000A',
        title: 'Empty',
        relativePath: 'A.md',
        frontmatter: {'forms': ''},
      );
      await seed(
        ulid: '01HX0V0000000000000000000B',
        title: 'Whitespace',
        relativePath: 'B.md',
        frontmatter: {'forms': '   '},
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('page with `forms: true` is included', () async {
      await seed(
        ulid: '01HX0V0000000000000000000A',
        title: 'Customer feedback',
        relativePath: 'Inbox/Customer feedback.md',
        frontmatter: {'forms': true},
      );
      final result = await repo.loadAll();
      expect(result, hasLength(1));
      expect(result.single.ulid, '01HX0V0000000000000000000A');
      expect(result.single.title, 'Customer feedback');
      expect(result.single.relativePath, 'Inbox/Customer feedback.md');
      expect(result.single.formsRef, 'true');
    });

    test('page with `forms: <db-ref>` preserves the path string', () async {
      await seed(
        ulid: '01HX0V0000000000000000000A',
        title: 'Bug reports',
        relativePath: 'Operations/Bugs.md',
        frontmatter: {'forms': 'Operations/Bugs.database.yaml'},
      );
      final result = await repo.loadAll();
      expect(result.single.formsRef, 'Operations/Bugs.database.yaml');
    });

    test('result is sorted alphabetically by title (case-insensitive)',
        () async {
      await seed(
          ulid: '01HX0V0000000000000000000A',
          title: 'Zeta',
          relativePath: 'Z.md',
          frontmatter: {'forms': true});
      await seed(
          ulid: '01HX0V0000000000000000000B',
          title: 'alpha',
          relativePath: 'a.md',
          frontmatter: {'forms': true});
      await seed(
          ulid: '01HX0V0000000000000000000C',
          title: 'Mike',
          relativePath: 'M.md',
          frontmatter: {'forms': true});
      final titles =
          (await repo.loadAll()).map((p) => p.title).toList();
      expect(titles, ['alpha', 'Mike', 'Zeta']);
    });

    test('mixed: form-bearing + plain pages — only form-bearing returned',
        () async {
      await seed(ulid: '01HX0V0000000000000000000A', title: 'Plain', relativePath: 'p.md');
      await seed(
        ulid: '01HX0V0000000000000000000B',
        title: 'Survey',
        relativePath: 's.md',
        frontmatter: {'forms': true},
      );
      await seed(
        ulid: '01HX0V0000000000000000000C',
        title: 'Empty form',
        relativePath: 'e.md',
        frontmatter: {'forms': ''},
      );
      await seed(
        ulid: '01HX0V0000000000000000000D',
        title: 'Bug report form',
        relativePath: 'b.md',
        frontmatter: {'forms': 'Bugs.yaml'},
      );
      final result = await repo.loadAll();
      expect(result.map((p) => p.ulid).toList(),
          ['01HX0V0000000000000000000D', '01HX0V0000000000000000000B']);
    });

    test('malformed frontmatterJson row is skipped (defensive)', () async {
      // Insert a row whose frontmatterJson isn't valid JSON. The repo
      // should not crash the whole load — it just skips the row.
      await db.into(db.pages).insert(PagesCompanion.insert(
            ulid: '01HX0V0000000000000BROKEN1',
            relativePath: 'broken.md',
            title: 'Broken',
            frontmatterJson: '{ this is not json',
            bodyText: '',
            mtimeMs: const Value(0),
          ));
      await seed(
        ulid: '01HX0V000000000000000000OK',
        title: 'Working',
        relativePath: 'ok.md',
        frontmatter: {'forms': true},
      );
      final result = await repo.loadAll();
      expect(result.map((p) => p.ulid).toList(),
          ['01HX0V000000000000000000OK']);
    });
  });
}
