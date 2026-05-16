// First slice of the VaultBloc bloc_test (RULES.md TS-03, A10 of the 1m-loop
// plan). VaultBloc has no existing dedicated test, so this file is being
// built incrementally: this iteration adds the simplest LoadFromPath path
// (missing directory → VaultError) which is fully self-contained and
// doesn't require Indexer / Drift / FilePicker behavior.
//
// Subsequent iterations will add: PickVault, LoadFromPath happy-path,
// RefreshFromDisk, CreatePage, MoveToTrash, ToggleFavorite, DuplicatePage,
// MovePage, RenamePage, CreateFolder, CloseVault, ToggleFolder.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/vault_watcher.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';

class _MockVaultRepository extends Mock implements VaultRepository {}

class _MockIndexer extends Mock implements Indexer {}

class _MockDb extends Mock implements QuillDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultBloc', () {
    late _MockVaultRepository repo;
    late _MockIndexer indexer;
    late _MockDb db;
    late VaultWatcher watcher;

    setUp(() {
      repo = _MockVaultRepository();
      indexer = _MockIndexer();
      db = _MockDb();
      // Real watcher; never call watch() so it stays inert. The bloc's
      // close() awaits dispose() which is safe on an unwatched controller.
      watcher = VaultWatcher();
    });

    VaultBloc buildBloc() => VaultBloc(
          repo: repo,
          indexer: indexer,
          db: db,
          watcher: watcher,
        );

    blocTest<VaultBloc, VaultState>(
      'LoadFromPath emits VaultError when the directory does not exist',
      build: buildBloc,
      act: (bloc) => bloc.add(
        const LoadFromPath('/definitely/not/a/real/path/quill_test'),
      ),
      expect: () => const [
        VaultError(
          'Vault not found: /definitely/not/a/real/path/quill_test',
        ),
      ],
      verify: (bloc) {
        // No indexer / db / repo calls should have happened on this path.
        verifyZeroInteractions(indexer);
        verifyZeroInteractions(db);
        verifyZeroInteractions(repo);
      },
    );
  });
}
