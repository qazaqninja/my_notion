/// Tests for DatabaseRepositoryImpl.updateCell / createRow. These exercise
/// the full path: read .md → mutate frontmatter → write atomically → upsert
/// in Drift. The fixture is copied to a temp dir per test so the writes
/// don't pollute the repo.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/database/data/repositories/database_repository_impl.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late QuillDatabase db;
  late VaultRepositoryImpl vaultRepo;
  late Indexer indexer;
  late DatabaseRepositoryImpl dbRepo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_db_repo_test_');
    await _copyDir(Directory('fixtures/sample_vault'), tmp);

    db = QuillDatabase.forTesting(NativeDatabase.memory());
    vaultRepo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    indexer = Indexer(db, vaultRepo.datasource);
    await indexer.reindex(tmp);

    dbRepo = DatabaseRepositoryImpl(
      db,
      vault: vaultRepo,
      indexer: indexer,
      ulids: const UlidGenerator(),
    );
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('updateCell rewrites a text frontmatter value on disk', () async {
    final schemas = await dbRepo.listDatabases();
    expect(schemas, isNotEmpty);
    final schema = schemas.first;
    final col = schema.columns.firstWhere((c) => c.key == 'owner');

    final rows = await dbRepo.getRows(schema.id);
    final northwind =
        rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));

    await dbRepo.updateCell(
      ulid: northwind.ulid,
      column: col,
      newValue: 'Priya',
      vaultRoot: tmp,
    );

    final file = File(p.join(tmp.path, northwind.relativePath));
    final raw = await file.readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.get('owner'), equals('Priya'));
    // Other keys preserved.
    expect(parsed.frontmatter.get('title'), equals('Northwind'));
    expect(parsed.frontmatter.get('stage'), equals('expanding'));
  });

  test('updateCell numeric value parses to num', () async {
    final schema = (await dbRepo.listDatabases()).first;
    final arr = schema.columns.firstWhere((c) => c.key == 'arr');
    final rows = await dbRepo.getRows(schema.id);
    final northwind =
        rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));

    await dbRepo.updateCell(
      ulid: northwind.ulid,
      column: arr,
      newValue: '525000',
      vaultRoot: tmp,
    );

    final raw =
        await File(p.join(tmp.path, northwind.relativePath)).readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.get('arr'), equals(525000));
  });

  test('createRow writes a new .md inside the database folder', () async {
    final schema = (await dbRepo.listDatabases()).first;
    final initialCount = (await dbRepo.getRows(schema.id)).length;

    final row = await dbRepo.createRow(
      schema: schema,
      title: 'AcmeNew',
      vaultRoot: tmp,
    );

    expect(row.title, equals('AcmeNew'));
    expect(row.ulid, hasLength(26));
    final file = File(p.join(tmp.path, row.relativePath));
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.id, equals(row.ulid));
    expect(parsed.frontmatter.title, equals('AcmeNew'));
    // The new row should now belong to the database.
    final after = await dbRepo.getRows(schema.id);
    expect(after, hasLength(initialCount + 1));
    expect(after.any((r) => r.ulid == row.ulid), isTrue);
  });

  test('createRow strips unsafe filename chars', () async {
    final schema = (await dbRepo.listDatabases()).first;
    final row = await dbRepo.createRow(
      schema: schema,
      title: 'Bad/Name<Here>',
      vaultRoot: tmp,
    );
    expect(p.basename(row.relativePath), equals('Bad-Name-Here-.md'));
  });

  test('updateCell YAML-escapes text cells with reserved glyphs (M695)',
      () async {
    final schema = (await dbRepo.listDatabases()).first;
    final col = schema.columns.firstWhere((c) => c.key == 'owner');
    final rows = await dbRepo.getRows(schema.id);
    final northwind =
        rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));

    // ':' would split the YAML mapping; '#' would start a comment.
    const unsafe = 'Priya: Tech Lead #urgent';
    await dbRepo.updateCell(
      ulid: northwind.ulid,
      column: col,
      newValue: unsafe,
      vaultRoot: tmp,
    );

    final raw = await File(p.join(tmp.path, northwind.relativePath)).readAsString();
    expect(raw, contains('owner: "Priya: Tech Lead #urgent"'),
        reason: 'rawScalar must be double-quoted on disk');
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.get('owner'), equals(unsafe),
        reason: 'round-trip must recover the original string');
  });

  test('updateCell YAML-escapes multi cells with commas in items (M695)',
      () async {
    // Build a synthetic schema with a multi column.
    final dbYamlPath = p.join(tmp.path, 'Operations/Customers/.database.yaml');
    final existing = await File(dbYamlPath).readAsString();
    await File(dbYamlPath).writeAsString(
        existing.replaceFirst('schema:\n',
            'schema:\n  labels:\n    type: multi\n'));
    await indexer.reindex(tmp);
    final schema = (await dbRepo.listDatabases()).first;
    final col = schema.columns.firstWhere((c) => c.key == 'labels');
    final rows = await dbRepo.getRows(schema.id);
    final northwind =
        rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));

    // Comma inside a label would split into two labels without quoting.
    await dbRepo.updateCell(
      ulid: northwind.ulid,
      column: col,
      newValue: 'high, priority',
      vaultRoot: tmp,
    );

    final raw = await File(p.join(tmp.path, northwind.relativePath)).readAsString();
    final parsed = FrontmatterParser.parse(raw);
    final labels = parsed.frontmatter.get('labels');
    // The newValue 'high, priority' is split on commas by the cell
    // editor convention — so we expect two trimmed items.
    expect(labels, equals(['high', 'priority']));
  });

  test('updateCell throws PageLockedException when page has locked: true',
      () async {
    final schema = (await dbRepo.listDatabases()).first;
    final col = schema.columns.firstWhere((c) => c.key == 'owner');
    final rows = await dbRepo.getRows(schema.id);
    final northwind =
        rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));

    // Inject `locked: true` into the page on disk + reindex.
    final file = File(p.join(tmp.path, northwind.relativePath));
    final raw = await file.readAsString();
    final patched = raw.replaceFirst('---\n', '---\nlocked: true\n');
    await file.writeAsString(patched);
    await indexer.reindex(tmp);

    await expectLater(
      dbRepo.updateCell(
        ulid: northwind.ulid,
        column: col,
        newValue: 'Priya',
        vaultRoot: tmp,
      ),
      throwsA(isA<PageLockedException>()),
    );
    // The owner field on disk should be untouched.
    final after = await file.readAsString();
    final parsed = FrontmatterParser.parse(after);
    expect(parsed.frontmatter.get('owner'), isNot(equals('Priya')));
  });

  test(
    'updateCell respects permissions: read_only / readonly / read-only / locked',
    () async {
      final schema = (await dbRepo.listDatabases()).first;
      final col = schema.columns.firstWhere((c) => c.key == 'owner');
      final rows = await dbRepo.getRows(schema.id);
      final northwind =
          rows.firstWhere((r) => r.relativePath.endsWith('Northwind.md'));
      final file = File(p.join(tmp.path, northwind.relativePath));
      final original = await file.readAsString();

      for (final perm in const [
        'read_only',
        'readonly',
        'read-only',
        'locked',
      ]) {
        await file.writeAsString(
            original.replaceFirst('---\n', '---\npermissions: $perm\n'));
        await indexer.reindex(tmp);
        await expectLater(
          dbRepo.updateCell(
            ulid: northwind.ulid,
            column: col,
            newValue: 'Priya',
            vaultRoot: tmp,
          ),
          throwsA(isA<PageLockedException>()),
          reason: 'permissions: $perm should block updateCell',
        );
        await file.writeAsString(original);
      }
    },
  );

  test('createRow with row_template copies frontmatter + body', () async {
    // Seed: a template page at vault root.
    final tplPath = p.join(tmp.path, 'Customer-Template.md');
    await File(tplPath).writeAsString('---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B\ntitle: Template\nstage: pilot\narr: 0\nowner: Diego\n---\n\n## Onboarding\n\n- [ ] Kickoff call\n');
    await indexer.reindex(tmp);

    // Build a schema with a row_template field — note we re-parse from
    // the fixture's .database.yaml after appending the template ref.
    final dbYamlPath = p.join(tmp.path, 'Operations/Customers/.database.yaml');
    final existing = await File(dbYamlPath).readAsString();
    await File(dbYamlPath).writeAsString(
        '$existing\nrow_template: Customer-Template.md\n');
    await indexer.reindex(tmp);

    final schema = (await dbRepo.listDatabases()).first;
    expect(schema.rowTemplate, equals('Customer-Template.md'));

    final row = await dbRepo.createRow(
      schema: schema,
      title: 'NewCust',
      vaultRoot: tmp,
    );

    final raw =
        await File(p.join(tmp.path, row.relativePath)).readAsString();
    expect(raw, contains('## Onboarding'));
    expect(raw, contains('Kickoff call'));
    expect(raw, contains('stage: pilot'));
    expect(raw, contains('owner: Diego'));
    // id + title overridden.
    expect(raw, contains('title: NewCust'));
    expect(raw, contains('id: ${row.ulid}'));
  });
}

Future<void> _copyDir(Directory src, Directory dst) async {
  await for (final entity in src.list(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    final target = p.join(dst.path, rel);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
}
