/// THE day-one non-negotiable test from the build brief:
///
/// > Markdown is the source of truth. Drift is a cache. Nuking the SQLite
/// > file and re-indexing the filesystem must produce identical app state.
///
/// We seed a vault, reindex twice into two fresh in-memory databases, and
/// assert their snapshots are byte-identical.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';

void main() {
  test('reindex from sample_vault is idempotent — nuke and rebuild yields identical state',
      () async {
    final vault = Directory('fixtures/sample_vault');
    expect(vault.existsSync(), isTrue, reason: 'fixtures/sample_vault must exist');

    final ds = VaultFsDatasource(ulids: const UlidGenerator());

    // First run.
    final db1 = QuillDatabase.forTesting(NativeDatabase.memory());
    await Indexer(db1, ds).reindex(vault);
    final snap1 = await db1.snapshot();
    await db1.close();

    // Second run, completely fresh database.
    final db2 = QuillDatabase.forTesting(NativeDatabase.memory());
    await Indexer(db2, ds).reindex(vault);
    final snap2 = await db2.snapshot();
    await db2.close();

    expect(snap2, equals(snap1));
  });

  test('reindex finds wikilink relations between fixture pages', () async {
    final vault = Directory('fixtures/sample_vault');
    final ds = VaultFsDatasource(ulids: const UlidGenerator());
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    await Indexer(db, ds).reindex(vault);

    final relations = await db.select(db.relations).get();
    expect(relations, isNotEmpty);
    // Acmeco.md → 01HX0VEY... (Acmeco-renew)
    expect(
      relations.any((r) => r.toUlid == '01HX0VEY5T6K7R9X4Y8Z0A3D4G'),
      isTrue,
      reason: 'expected backlink to Acmeco-renew (01HX0VEY...) found in body',
    );
    // Acmeco-renew.md → 01HX0V9R... (Northwind)
    expect(
      relations.any((r) => r.toUlid == '01HX0V9R5N6E8L3P7Q8S9U2X4B'),
      isTrue,
      reason: 'expected forward link to Northwind (01HX0V9R...) found in body',
    );

    await db.close();
  });

  test('reindex inserts each .md page exactly once', () async {
    final vault = Directory('fixtures/sample_vault');
    final ds = VaultFsDatasource(ulids: const UlidGenerator());
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    await Indexer(db, ds).reindex(vault);

    final pages = await db.select(db.pages).get();
    // ULIDs are unique → no page is indexed twice.
    final ulids = pages.map((p) => p.ulid).toList();
    expect(ulids.toSet().length, ulids.length, reason: 'every page must be indexed exactly once');
    final titles = pages.map((p) => p.title).toSet();
    expect(
      titles,
      containsAll({
        'Acmeco',
        'Northwind',
        'Globex',
        'Initech',
        'Acmeco renewal',
        '2026 Q1 QBR',
        'Inbox',
      }),
    );
    await db.close();
  });
}
