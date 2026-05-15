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
  test('MovePage relocates the .md and re-indexes', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_move_test_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    // Seed: root + an Archive folder.
    await Directory(p.join(tmp.path, 'Archive')).create();

    bloc.add(LoadFromPath(tmp.path));
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    String? ulid;
    bloc.add(CreatePage(title: 'Doc', onCreated: (u) => ulid = u));
    while (ulid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Doc.md')).exists(), isTrue);

    // Move to Archive/. Wait for BOTH the filesystem move AND the
    // indexer's database row to land — the indexer updates the row
    // a tick after the FS rename, and under load the bare FS-only
    // poll can return early and trip the row assertion below.
    bloc.add(MovePage(ulid: ulid!, targetFolder: 'Archive'));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final fsMoved =
          await File(p.join(tmp.path, 'Archive', 'Doc.md')).exists() &&
              !await File(p.join(tmp.path, 'Doc.md')).exists();
      final row = await (db.select(db.pages)
            ..where((p) => p.ulid.equals(ulid!)))
          .getSingleOrNull();
      if (fsMoved && row?.relativePath == 'Archive/Doc.md') break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Doc.md')).exists(), isFalse);
    expect(await File(p.join(tmp.path, 'Archive', 'Doc.md')).exists(),
        isTrue);
    // Drift's row was updated to the new path.
    final row =
        await (db.select(db.pages)..where((p) => p.ulid.equals(ulid!)))
            .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.relativePath, equals('Archive/Doc.md'));

    // Move back to root. Same dual-poll pattern.
    bloc.add(MovePage(ulid: ulid!, targetFolder: ''));
    final deadline2 = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline2)) {
      final fsMoved =
          await File(p.join(tmp.path, 'Doc.md')).exists() &&
              !await File(p.join(tmp.path, 'Archive', 'Doc.md')).exists();
      final row2 = await (db.select(db.pages)
            ..where((p) => p.ulid.equals(ulid!)))
          .getSingleOrNull();
      if (fsMoved && row2?.relativePath == 'Doc.md') break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Doc.md')).exists(), isTrue);
    expect(await File(p.join(tmp.path, 'Archive', 'Doc.md')).exists(),
        isFalse);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
