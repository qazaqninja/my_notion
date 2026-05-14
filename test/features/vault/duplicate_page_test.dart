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
  test('DuplicatePage clones the .md with a fresh ULID and (copy) suffix',
      () async {
    final tmp = await Directory.systemTemp.createTemp('quill_dup_test_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    bloc.add(LoadFromPath(tmp.path));
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    String? sourceUlid;
    bloc.add(CreatePage(title: 'Original', onCreated: (u) => sourceUlid = u));
    while (sourceUlid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    String? copyUlid;
    bloc.add(DuplicatePage(sourceUlid!, onCreated: (u) => copyUlid = u));
    while (copyUlid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(copyUlid, isNot(equals(sourceUlid)));

    final original = File(p.join(tmp.path, 'Original.md'));
    final copy = File(p.join(tmp.path, 'Original (copy).md'));
    expect(await original.exists(), isTrue);
    expect(await copy.exists(), isTrue);

    final originalFm =
        FrontmatterParser.parse(await original.readAsString()).frontmatter;
    final copyFm =
        FrontmatterParser.parse(await copy.readAsString()).frontmatter;
    expect(originalFm.id, equals(sourceUlid));
    expect(copyFm.id, equals(copyUlid));
    expect(copyFm.title, equals('Original (copy)'));

    final allUlids = (await db.select(db.pages).get()).map((p) => p.ulid).toSet();
    expect(allUlids, containsAll([sourceUlid, copyUlid]));

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
