import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:path/path.dart' as p;

void main() {
  test('MoveToTrash moves .md to .trash/<YYYY-MM>/ and drops from drift', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_trash_test_');
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

    String? createdUlid;
    bloc.add(CreatePage(title: 'doomed', onCreated: (u) => createdUlid = u));
    while (createdUlid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'doomed.md')).exists(), isTrue);
    expect(((await db.select(db.pages).get()).length), 1);

    bloc.add(MoveToTrash(createdUlid!));
    // Wait for the move to land and a fresh tree to be emitted.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final s = bloc.state;
      if (s is VaultLoaded && s.pageCount == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(await File(p.join(tmp.path, 'doomed.md')).exists(), isFalse);
    final trashDir = Directory(p.join(tmp.path, '.trash'));
    expect(await trashDir.exists(), isTrue);
    final bucket =
        await trashDir.list().firstWhere((e) => e is Directory) as Directory;
    final files = await bucket.list().toList();
    expect(files, hasLength(1));
    expect(p.basename(files.first.path), 'doomed.md');
    expect((await db.select(db.pages).get()), isEmpty);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
