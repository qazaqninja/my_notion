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
  test('RenamePage keeps the folder, swaps the basename, re-indexes',
      () async {
    final tmp = await Directory.systemTemp.createTemp('quill_rename_test_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
        VaultFsDatasource(ulids: const UlidGenerator()));
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);
    await Directory(p.join(tmp.path, 'Folder')).create();

    bloc.add(LoadFromPath(tmp.path));
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    String? ulid;
    bloc.add(CreatePage(
        title: 'OldName',
        folderPath: 'Folder',
        onCreated: (u) => ulid = u));
    while (ulid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Folder', 'OldName.md')).exists(),
        isTrue);

    bloc.add(RenamePage(ulid: ulid!, newBasename: 'NewName'));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (await File(p.join(tmp.path, 'Folder', 'NewName.md')).exists() &&
          !await File(p.join(tmp.path, 'Folder', 'OldName.md')).exists()) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Folder', 'NewName.md')).exists(),
        isTrue);
    expect(await File(p.join(tmp.path, 'Folder', 'OldName.md')).exists(),
        isFalse);

    final row = await (db.select(db.pages)..where((p) => p.ulid.equals(ulid!)))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.relativePath, 'Folder/NewName.md');
    expect(row.ulid, equals(ulid));

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
