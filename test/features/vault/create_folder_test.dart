import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:path/path.dart' as p;

void main() {
  Future<VaultBloc> bootBloc(Directory tmp) async {
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo =
        VaultRepositoryImpl(VaultFsDatasource(ulids: const UlidGenerator()));
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);
    bloc.add(LoadFromPath(tmp.path));
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return bloc;
  }

  test('CreateFolder makes a fresh subfolder under root', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_mkdir_root_');
    final bloc = await bootBloc(tmp);

    bloc.add(const CreateFolder(parentFolder: '', name: 'Inbox'));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (await Directory(p.join(tmp.path, 'Inbox')).exists()) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await Directory(p.join(tmp.path, 'Inbox')).exists(), isTrue);

    // Wait for the bloc to emit the updated tree.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = bloc.state as VaultLoaded;
    final names = s.tree.topLevel.whereType<VaultFolder>().map((f) => f.name);
    expect(names, contains('Inbox'));

    await bloc.close();
    await tmp.delete(recursive: true);
  });

  test('CreateFolder nests under an existing parent', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_mkdir_nest_');
    await Directory(p.join(tmp.path, 'Projects')).create();
    final bloc = await bootBloc(tmp);

    bloc.add(const CreateFolder(parentFolder: 'Projects', name: 'Q3 launch'));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (await Directory(p.join(tmp.path, 'Projects', 'Q3 launch')).exists()) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(
        await Directory(p.join(tmp.path, 'Projects', 'Q3 launch')).exists(),
        isTrue);

    await bloc.close();
    await tmp.delete(recursive: true);
  });

  test('CreateFolder sanitises slashes / colons / ".." to dashes', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_mkdir_sanitise_');
    final bloc = await bootBloc(tmp);

    bloc.add(const CreateFolder(parentFolder: '', name: 'a/b:c'));
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (await Directory(p.join(tmp.path, 'a-b-c')).exists()) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await Directory(p.join(tmp.path, 'a-b-c')).exists(), isTrue);
    expect(await Directory(p.join(tmp.path, 'a')).exists(), isFalse);

    await bloc.close();
    await tmp.delete(recursive: true);
  });

  test('CreateFolder is a no-op for empty or "."-only names', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_mkdir_empty_');
    final bloc = await bootBloc(tmp);

    bloc.add(const CreateFolder(parentFolder: '', name: '   '));
    bloc.add(const CreateFolder(parentFolder: '', name: '.'));
    bloc.add(const CreateFolder(parentFolder: '', name: '..'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final entries = tmp.listSync().map((e) => p.basename(e.path)).toList();
    expect(entries, isEmpty);

    await bloc.close();
    await tmp.delete(recursive: true);
  });
}
