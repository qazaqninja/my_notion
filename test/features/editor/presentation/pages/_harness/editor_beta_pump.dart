import 'package:drift/native.dart';
import 'package:file/memory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';

/// Shared `pumpWidget` harness for `editor_beta_page_test.dart`
/// suites. Future per-handler smoke tests (mount → tap kebab →
/// assert dispatch) reuse this single helper instead of rebuilding
/// the provider stack in every file.
///
/// **Status:** sub-slice 2 (M1806). Three foundation providers
/// (VaultRepository + Indexer + QuillDatabase) are now wired via
/// in-memory fakes (drift `NativeDatabase.memory()` + `MemoryFileSystem`).
/// The helper mounts a probe widget that proves these are
/// resolvable via `context.read`. Subsequent sub-slices add the
/// remaining 6 collaborators (HtmlExportRepository,
/// PdfExportRepository, FormsRepository, VaultBloc, SyncBloc, and
/// the 3 self-provided blocs/cubits via the page itself) and
/// finally swap the probe for the actual `EditorBetaPage`.
///
/// **Provider stack the editor needs** (verified via grep on
/// `editor_beta_page.dart`):
///
/// * `RepositoryProvider<VaultRepository>` ✅ M1806
/// * `RepositoryProvider<Indexer>` ✅ M1806
/// * `RepositoryProvider<QuillDatabase>` ✅ M1806
/// * `RepositoryProvider<HtmlExportRepository>` (M1794) — queued
/// * `RepositoryProvider<PdfExportRepository>` (M1796) — queued
/// * `RepositoryProvider<FormsRepository>` (D-fp19, M1741) — queued
/// * `BlocProvider<VaultBloc>` (read for `rootPath`) — queued
/// * `BlocProvider<SyncBloc>` (read for `isAuthed`) — queued
/// * The editor provides `EditorBloc`, `SlashMenuCubit`, and
///   `BlockSelectionCubit` internally — drops out once the page
///   itself mounts.
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
Future<EditorBetaHarness> pumpEditorBeta(
  WidgetTester tester, {
  required String ulid,
  Widget? probe,
}) async {
  final fs = MemoryFileSystem();
  final ds = VaultFsDatasource(ulids: const UlidGenerator(), fs: fs);
  final db = QuillDatabase.forTesting(NativeDatabase.memory());
  final indexer = Indexer(db, ds);
  final repo = VaultRepositoryImpl(ds);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<VaultRepository>.value(value: repo),
        RepositoryProvider<Indexer>.value(value: indexer),
        RepositoryProvider<QuillDatabase>.value(value: db),
      ],
      child: probe ?? const _UnwiredPagePlaceholder(),
    ),
  );

  return EditorBetaHarness._(db: db, indexer: indexer, repo: repo, fs: fs);
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
  });

  final QuillDatabase db;
  final Indexer indexer;
  final VaultRepository repo;
  final MemoryFileSystem fs;

  /// Convenience cleanup hook so callers can `addTearDown(harness.dispose)`.
  Future<void> dispose() async {
    await db.close();
  }
}

/// Placeholder mounted when no `probe` widget is passed.  Future
/// sub-slices swap this for `EditorBetaPage(ulid: …)` once the
/// remaining 6 providers + 3 self-provided blocs are wired.
class _UnwiredPagePlaceholder extends StatelessWidget {
  const _UnwiredPagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
