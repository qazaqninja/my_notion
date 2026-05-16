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
import 'package:shared_preferences/shared_preferences.dart';

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
      // VaultBloc's PickVault/LoadFromPath/CloseVault read/write the saved
      // vault path, so SharedPreferences must be mocked or `getInstance()`
      // hangs forever in pure-Dart tests.
      SharedPreferences.setMockInitialValues({});
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

    // ────────────────────────────────────────────────────────────────────
    // Slice 2 (M1206): CloseVault + the 7 events that no-op outside
    // VaultLoaded state.
    //
    // All 7 of these handlers start with `if (state is! VaultLoaded) return;`
    // so when fired from `VaultInitial`, they must emit nothing AND must
    // not call any of the mocked dependencies. This lets the bloc be added
    // to a UI before a vault is loaded without risking spurious state
    // flicker or premature side effects.
    // ────────────────────────────────────────────────────────────────────

    blocTest<VaultBloc, VaultState>(
      'CloseVault: stops watcher, clears indexer, transitions to VaultInitial',
      // Seed with VaultPicking so the Initial-after-emit is an observable
      // transition rather than a dedup-suppressed re-emission.
      seed: () => const VaultPicking(),
      build: () {
        when(() => indexer.clearAll()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CloseVault()),
      expect: () => const [VaultInitial()],
      verify: (bloc) {
        verify(() => indexer.clearAll()).called(1);
      },
    );

    for (final entry in <String, VaultEvent>{
      'ToggleFolder': const ToggleFolder('Inbox'),
      'ReindexVault': const ReindexVault(),
      'CreatePage': const CreatePage(title: 'X'),
      'MoveToTrash': const MoveToTrash('01HZZZZ'),
      'DuplicatePage': const DuplicatePage('01HZZZZ'),
      'ToggleFavorite': const ToggleFavorite('01HZZZZ'),
      'MovePage': const MovePage(ulid: '01HZZZZ', targetFolder: 'X'),
      'RenamePage': const RenamePage(ulid: '01HZZZZ', newBasename: 'X'),
      'CreateFolder': const CreateFolder(parentFolder: '', name: 'X'),
    }.entries) {
      blocTest<VaultBloc, VaultState>(
        '${entry.key} is a no-op when state is VaultInitial',
        build: buildBloc,
        act: (bloc) => bloc.add(entry.value),
        expect: () => const <VaultState>[],
        verify: (bloc) {
          verifyZeroInteractions(indexer);
          verifyZeroInteractions(repo);
        },
      );
    }
  });
}
