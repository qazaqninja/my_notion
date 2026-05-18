import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/editor/data/repositories/html_export_repository_impl.dart';
import 'package:my_notion/features/editor/data/repositories/pdf_export_repository_impl.dart';
import 'package:my_notion/features/editor/domain/repositories/html_export_repository.dart';
import 'package:my_notion/features/editor/domain/repositories/pdf_export_repository.dart';
import 'package:my_notion/features/editor/presentation/pages/editor_beta_page.dart';
import 'package:my_notion/features/forms/domain/entities/form_submission.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';

// TS-05 exception: shared harness by design — every per-handler
// test file imports `pumpEditorBeta` + `EditorBetaHarness` from
// this file rather than re-declaring a private clone. See the
// M1806 orchestrator audit for the explicit acknowledgement.

/// Shared `pumpWidget` harness for `editor_beta_page_test.dart`
/// suites. Future per-handler smoke tests (mount → tap kebab →
/// assert dispatch) reuse this single helper instead of rebuilding
/// the provider stack in every file.
///
/// **Status:** sub-slice 5 FINAL (M1813). All 9 collaborators
/// now wired — the 3 M1806 foundations (VaultRepository + Indexer +
/// QuillDatabase) plus the 3 added in this slice
/// (HtmlExportRepository + PdfExportRepository + FormsRepository).
/// The two ExportRepository impls are stateless `const Impl()`
/// (they wrap the M1794/M1796 pure-function adapters already
/// covered in `vault/data/` tests). FormsRepository uses a tiny
/// in-test `_NoopFormsRepository` that returns empty submission
/// lists — the auth-gated `listSubmissions` is only invoked from
/// `_onViewFormSubmissions` (D-fp19, M1741), and an empty list is
/// the same shape the kebab handler sees from the real backend
/// when no forms have been submitted yet.
///
/// Subsequent sub-slices add the remaining 3 collaborators
/// (VaultBloc + SyncBloc + the page itself, which internally
/// provides EditorBloc + SlashMenuCubit + BlockSelectionCubit) and
/// finally swap the probe for the actual `EditorBetaPage`.
///
/// **Provider stack the editor needs** (verified via grep on
/// `editor_beta_page.dart`):
///
/// * `RepositoryProvider<VaultRepository>` ✅ M1806
/// * `RepositoryProvider<Indexer>` ✅ M1806
/// * `RepositoryProvider<QuillDatabase>` ✅ M1806
/// * `RepositoryProvider<HtmlExportRepository>` (M1794) ✅ M1809
/// * `RepositoryProvider<PdfExportRepository>` (M1796) ✅ M1809
/// * `RepositoryProvider<FormsRepository>` (D-fp19, M1741) ✅ M1809
/// * `BlocProvider<VaultBloc>` (read for `rootPath`) ✅ M1811
/// * `BlocProvider<SyncBloc>` (read for `isAuthed`) ✅ M1811
/// * The editor provides `EditorBloc`, `SlashMenuCubit`, and
///   `BlockSelectionCubit` internally via the page's own
///   `MultiBlocProvider` ✅ M1813 (default probe is now the page
///   itself, wrapped in `MaterialApp`).
///
/// **Wiring options when more handlers come in scope:**
///
/// * For pure widget-construction smoke (no interaction),
///   `MockBloc` stubs that emit a single initial state are enough.
/// * For dispatch-assertion tests (tap kebab → expect event),
///   each consumed bloc needs `whenListen` + `verify(...).called(1)`
///   per the M1571 BL-11 carry-forward pattern.
/// * `GoRouter` mock via mockingjay (`MockGoRouter` already wired
///   via `test/foundation/mockingjay_smoke_test.dart`).
///
/// **Why iterative:** EditorBetaPage has 9 collaborators, so
/// landing the full harness in a single slice would balloon past
/// the loop's bite-sized budget. Splitting per-collaborator keeps
/// each iteration small + lets the orchestrator gate each addition.
/// When [probe] is null the default mount is the real
/// `EditorBetaPage(ulid:)` wrapped in `MaterialApp.router` so the
/// page can resolve `Directionality` + `MediaQuery` + `GoRouter`
/// (the AppBar uses `GoRouter.of(context).go(...)` for nav back to
/// `/home` after Move-to-Trash). Pass an override `probe:` (a
/// `Builder` or a different widget) to drive the legacy
/// foundation/probe assertions from M1806/M1809/M1811.
Future<EditorBetaHarness> pumpEditorBeta(
  WidgetTester tester, {
  required String ulid,
  Widget? probe,
  bool seedPage = false,
  String seedTitle = 'Test',
  String seedBody = 'Hello.',
}) async {
  final fs = MemoryFileSystem();
  const rootPath = '/vault';
  final ds = VaultFsDatasource(ulids: const UlidGenerator(), fs: fs);
  final db = QuillDatabase.forTesting(NativeDatabase.memory());
  final indexer = Indexer(db, ds);
  final repo = VaultRepositoryImpl(ds);
  final vaultBloc = _StubVaultBloc();
  final syncBloc = _StubSyncBloc();
  final VaultState vaultState;
  if (seedPage) {
    final root = fs.directory(rootPath)..createSync(recursive: true);
    root.childFile('page.md').writeAsStringSync(
          '---\nid: $ulid\ntitle: $seedTitle\n---\n\n$seedBody\n',
        );
    await indexer.reindex(root);
    vaultState = VaultLoaded(
      rootPath: rootPath,
      tree: VaultTree.empty,
      expandedFolders: const <String>{},
      pageCount: 1,
    );
  } else {
    vaultState = const VaultInitial();
  }
  whenListen(vaultBloc, const Stream<VaultState>.empty(),
      initialState: vaultState);
  whenListen(syncBloc, const Stream<SyncState>.empty(),
      initialState: const SyncState());

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<VaultRepository>.value(value: repo),
        RepositoryProvider<Indexer>.value(value: indexer),
        RepositoryProvider<QuillDatabase>.value(value: db),
        RepositoryProvider<HtmlExportRepository>(
          create: (_) => const HtmlExportRepositoryImpl(),
        ),
        RepositoryProvider<PdfExportRepository>(
          create: (_) => const PdfExportRepositoryImpl(),
        ),
        RepositoryProvider<FormsRepository>(
          create: (_) => const _NoopFormsRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<VaultBloc>.value(value: vaultBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
        ],
        child: probe ?? _defaultProbe(ulid: ulid),
      ),
    ),
  );

  return EditorBetaHarness._(
    db: db,
    indexer: indexer,
    repo: repo,
    fs: fs,
    vaultBloc: vaultBloc,
    syncBloc: syncBloc,
  );
}

class _StubVaultBloc extends MockBloc<VaultEvent, VaultState>
    implements VaultBloc {}

class _StubSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

/// In-test stand-in for [FormsRepository] that returns an empty
/// submission list. The only consumer in `editor_beta_page.dart` is
/// `_onViewFormSubmissions` (D-fp19, M1741), which shows an empty
/// state when there are no rows — exactly the shape this stub
/// produces. Per-handler slices that need richer behavior (e.g.,
/// "tap row → open detail") will override the impl via the
/// `RepositoryProvider<FormsRepository>` they wrap around their
/// own `pumpEditorBeta` call.
class _NoopFormsRepository implements FormsRepository {
  const _NoopFormsRepository();

  @override
  Future<List<FormSubmission>> listSubmissions({
    required String token,
    required String ulid,
  }) async {
    return const [];
  }
}

/// Handles returned from [pumpEditorBeta] so per-handler slices can
/// reach into the in-memory backing stores (e.g., seed pages on the
/// filesystem before the EditorBloc opens the page).
class EditorBetaHarness {
  EditorBetaHarness._({
    required this.db,
    required this.indexer,
    required this.repo,
    required this.fs,
    required this.vaultBloc,
    required this.syncBloc,
  });

  final QuillDatabase db;
  final Indexer indexer;
  final VaultRepository repo;
  final MemoryFileSystem fs;
  final VaultBloc vaultBloc;
  final SyncBloc syncBloc;

  /// Convenience cleanup hook so callers can `addTearDown(harness.dispose)`.
  ///
  /// As of M1811 closes the two MockBloc stubs alongside the in-memory
  /// drift database.  Stream subscriptions and open file handles will
  /// land here as later sub-slices wire them.
  Future<void> dispose() async {
    await vaultBloc.close();
    await syncBloc.close();
    await db.close();
  }
}

/// Default mount: real `EditorBetaPage(ulid:)` inside a minimal
/// `MaterialApp.router` (GoRouter shell needed by the page's
/// `GoRouter.of(context).go(...)` calls in the Move-to-Trash
/// kebab handler).
Widget _defaultProbe({required String ulid}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/editor/$ulid',
      routes: [
        GoRoute(
          path: '/editor/:ulid',
          builder: (_, state) => EditorBetaPage(
            ulid: state.pathParameters['ulid']!,
          ),
        ),
        GoRoute(path: '/home', builder: (_, _) => const SizedBox.shrink()),
      ],
    ),
  );
}
