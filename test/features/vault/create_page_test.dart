import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:path/path.dart' as p;

void main() {
  test('CreatePage writes a new .md at the vault root and indexes it', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_create_page_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    bloc.add(LoadFromPath(tmp.path));
    // Wait for VaultLoaded to settle.
    final loadedAt = DateTime.now();
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(loadedAt).inSeconds > 3) {
        fail('Vault never reached VaultLoaded: ${bloc.state}');
      }
    }

    String? createdUlid;
    bloc.add(CreatePage(title: 'Hello world', onCreated: (u) => createdUlid = u));
    final createdAt = DateTime.now();
    while (createdUlid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(createdAt).inSeconds > 3) {
        fail('onCreated never fired');
      }
    }

    final file = File(p.join(tmp.path, 'Hello world.md'));
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.id, equals(createdUlid));
    expect(parsed.frontmatter.title, equals('Hello world'));

    // The new page is in Drift.
    final pages = await db.select(db.pages).get();
    expect(pages.any((row) => row.ulid == createdUlid), isTrue);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
