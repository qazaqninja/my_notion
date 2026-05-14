import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/data/workspace_config.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:path/path.dart' as p;

void main() {
  test('ToggleFavorite adds then removes, writing through .quill.yaml',
      () async {
    final tmp = await Directory.systemTemp.createTemp('quill_fav_test_');
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

    String? ulid;
    bloc.add(CreatePage(title: 'Foo', onCreated: (u) => ulid = u));
    while (ulid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // Pin
    bloc.add(ToggleFavorite(ulid!));
    final pinDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(pinDeadline)) {
      final s = bloc.state;
      if (s is VaultLoaded && s.workspace.favorites.contains(ulid)) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect((bloc.state as VaultLoaded).workspace.favorites, contains(ulid));
    expect(await File(p.join(tmp.path, '.quill.yaml')).exists(), isTrue);
    final reloaded1 = await WorkspaceConfig.load(tmp);
    expect(reloaded1.favorites, contains(ulid));

    // Unpin
    bloc.add(ToggleFavorite(ulid!));
    final unpinDeadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(unpinDeadline)) {
      final s = bloc.state;
      if (s is VaultLoaded && !s.workspace.favorites.contains(ulid)) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect((bloc.state as VaultLoaded).workspace.favorites, isEmpty);
    final reloaded2 = await WorkspaceConfig.load(tmp);
    expect(reloaded2.favorites, isEmpty);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
