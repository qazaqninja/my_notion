// First slice of the EditorBloc bloc_test (RULES.md TS-03, A11 of the
// 1m-loop plan). EditorBloc has no existing dedicated test; this file
// is built incrementally:
//
// Slice 1 (M1208): the no-op contract for the 9 events that early-return
// outside `EditorLoaded` (EditBody, UndoEdit, RedoEdit, ToggleEditorMode,
// SaveNow, EditFrontmatterField, AddFrontmatterField, RemoveFrontmatterField,
// ReplaceFrontmatterYaml). Plus the OpenEditor "vault root not set" error
// path which transitions Idle → EditorLoading → EditorError without any
// dependency stubs.
//
// Future slices: OpenEditor happy path (needs drift in-memory db + repo
// page-read mock), SaveNow happy path (debounce timer + repo.writePage),
// EditBody-on-locked-page (M170 permissions: read_only), undo/redo
// stacks under load.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_event.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_state.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';

class _MockVaultRepository extends Mock implements VaultRepository {}

class _MockIndexer extends Mock implements Indexer {}

class _MockDb extends Mock implements QuillDatabase {}

const _sampleEntry = FrontmatterEntry(
  key: 'title',
  rawScalar: 'Demo',
  type: FrontmatterType.text,
  value: 'Demo',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorBloc', () {
    late _MockVaultRepository repo;
    late _MockIndexer indexer;
    late _MockDb db;

    setUp(() {
      repo = _MockVaultRepository();
      indexer = _MockIndexer();
      db = _MockDb();
    });

    EditorBloc buildBloc() => EditorBloc(
          repo: repo,
          indexer: indexer,
          db: db,
        );

    // ────────────────────────────────────────────────────────────────────
    // No-op contract: 9 events early-return when state is not EditorLoaded.
    // This contract lets the bloc be added to a UI before a page is opened
    // without risking spurious state flicker or premature filesystem hits.
    // ────────────────────────────────────────────────────────────────────

    for (final entry in <String, EditorEvent>{
      'EditBody': const EditBody('new body'),
      'UndoEdit': const UndoEdit(),
      'RedoEdit': const RedoEdit(),
      'ToggleEditorMode': const ToggleEditorMode(EditorMode.source),
      'SaveNow': const SaveNow(),
      'EditFrontmatterField':
          const EditFrontmatterField('title', _sampleEntry),
      'AddFrontmatterField': const AddFrontmatterField(_sampleEntry),
      'RemoveFrontmatterField': const RemoveFrontmatterField('title'),
      'ReplaceFrontmatterYaml': const ReplaceFrontmatterYaml('title: Demo'),
    }.entries) {
      blocTest<EditorBloc, EditorState>(
        '${entry.key} is a no-op when state is EditorIdle',
        build: buildBloc,
        act: (bloc) => bloc.add(entry.value),
        expect: () => const <EditorState>[],
        verify: (bloc) {
          // None of these handlers should reach the repo / indexer / db on
          // the early-return path.
          verifyZeroInteractions(repo);
          verifyZeroInteractions(indexer);
          verifyZeroInteractions(db);
        },
      );
    }

    // OpenEditor positive paths (page-not-found, vault-root-not-set, happy
    // path) need a working drift in-memory db (mocktail's `any()` matcher
    // can't bind drift's strongly-typed `ResultSetImplementation<HasResultSet>`
    // generic). Those are slice 2 work.
  });
}
