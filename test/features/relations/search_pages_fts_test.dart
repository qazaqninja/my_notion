/// Confirms FTS5 is actually being queried (FEATURES.md flagged this).
/// We seed pages with distinctive body content and verify that searching
/// for words from the body — NOT from the title — returns the right page.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/relations/domain/usecases/search_pages.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';

void main() {
  test('FTS5 search hits body content, not just titles', () async {
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final ds = VaultFsDatasource(ulids: const UlidGenerator());
    final indexer = Indexer(db, ds);
    await indexer.reindex(Directory('fixtures/sample_vault'));

    final search = SearchPages(db);

    // "Logistics" appears in Northwind's body, not its title.
    final logistics = await search('Logistics');
    expect(logistics, isNotEmpty);
    expect(logistics.first.title, equals('Northwind'));

    // "QBR" only appears in 2026-Q1-QBR's title.
    final qbr = await search('QBR');
    expect(qbr.map((r) => r.title), contains('2026 Q1 QBR'));

    // Empty query returns recent pages (no FTS).
    final empty = await search('');
    expect(empty, isNotEmpty);

    await db.close();
  });

  test('FTS5 query with special chars is sanitized', () async {
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final ds = VaultFsDatasource(ulids: const UlidGenerator());
    final indexer = Indexer(db, ds);
    await indexer.reindex(Directory('fixtures/sample_vault'));

    final search = SearchPages(db);

    // Double-quotes in the query should not break the FTS MATCH expression.
    final r = await search('"Northwind"');
    expect(r, isNotEmpty);
    expect(r.first.title, equals('Northwind'));

    await db.close();
  });
}
