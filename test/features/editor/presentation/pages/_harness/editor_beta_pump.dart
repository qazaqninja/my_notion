import 'package:drift/native.dart';
import 'package:file/memory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/editor/data/repositories/html_export_repository_impl.dart';
import 'package:my_notion/features/editor/data/repositories/pdf_export_repository_impl.dart';
import 'package:my_notion/features/editor/domain/repositories/html_export_repository.dart';
import 'package:my_notion/features/editor/domain/repositories/pdf_export_repository.dart';
import 'package:my_notion/features/forms/domain/entities/form_submission.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';

// TS-05 exception: shared harness by design — every per-handler
// test file imports `pumpEditorBeta` + `EditorBetaHarness` from
// this file rather than re-declaring a private clone. See the
// M1806 orchestrator audit for the explicit acknowledgement.

/// Shared `pumpWidget` harness for `editor_beta_page_test.dart`
/// suites. Future per-handler smoke tests (mount → tap kebab →
/// assert dispatch) reuse this single helper instead of rebuilding
/// the provider stack in every file.
///
/// **Status:** sub-slice 3 (M1809). 6 of 9 collaborators now
/// wired — the 3 M1806 foundations (VaultRepository + Indexer +
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
      child: probe ?? const _UnwiredPagePlaceholder(),
    ),
  );

  return EditorBetaHarness._(db: db, indexer: indexer, repo: repo, fs: fs);
}

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
  });

  final QuillDatabase db;
  final Indexer indexer;
  final VaultRepository repo;
  final MemoryFileSystem fs;

  /// Convenience cleanup hook so callers can `addTearDown(harness.dispose)`.
  ///
  /// TODO: expand `dispose()` as new resources are wired in
  /// successive sub-slices (e.g., bloc.close() once VaultBloc /
  /// SyncBloc fakes land; stream subscriptions; open file handles).
  /// Today only `db.close()` is needed — `MemoryFileSystem` has no
  /// close contract and `Indexer`/`VaultRepositoryImpl` are
  /// stateless.
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
