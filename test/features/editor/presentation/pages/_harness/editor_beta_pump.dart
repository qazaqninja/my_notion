import 'package:flutter_test/flutter_test.dart';

/// Shared `pumpWidget` harness for `editor_beta_page_test.dart`
/// suites. Future per-handler smoke tests (mount → tap kebab →
/// assert dispatch) reuse this single helper instead of rebuilding
/// the provider stack in every file.
///
/// **Status:** scaffold (M1804). Today the helper is a typed stub
/// that documents the required provider stack and throws when
/// invoked — every per-handler slice that follows will fill in one
/// missing collaborator at a time (TDD-driven), so the surface
/// stays auditable.
///
/// **Provider stack the editor needs** (verified via grep on
/// `editor_beta_page.dart`):
///
/// * `RepositoryProvider<VaultRepository>`
/// * `RepositoryProvider<Indexer>`
/// * `RepositoryProvider<QuillDatabase>`
/// * `RepositoryProvider<HtmlExportRepository>` (M1794)
/// * `RepositoryProvider<PdfExportRepository>` (M1796)
/// * `RepositoryProvider<FormsRepository>` (used by the
///   `_onViewFormSubmissions` handler — D-fp19, M1741)
/// * `BlocProvider<VaultBloc>` (read for `rootPath` in handlers)
/// * `BlocProvider<SyncBloc>` (read for `isAuthed` in handlers)
/// * The editor itself provides `EditorBloc`, `SlashMenuCubit`,
///   and `BlockSelectionCubit` internally (see
///   `editor_beta_page.dart:106` `build()`).
///
/// **Wiring options when an implementation lands:**
///
/// * For pure widget-construction smoke (no interaction), bloc
///   `MockBloc` stubs that emit a single initial state are enough.
/// * For dispatch-assertion tests (tap kebab → expect event),
///   each consumed bloc needs `whenListen` + `verify(...).called(1)`
///   per the M1571 BL-11 carry-forward pattern.
/// * `GoRouter` mock via mockingjay (`MockGoRouter` already wired
///   via `test/foundation/mockingjay_smoke_test.dart`).
///
/// **Why a stub today:** EditorBetaPage has ~9 collaborators, so
/// landing the full harness in a single slice would balloon past
/// the loop's bite-sized budget. Splitting per-collaborator keeps
/// each iteration small + lets the orchestrator gate each addition.
Future<void> pumpEditorBeta(
  WidgetTester tester, {
  required String ulid,
}) async {
  throw UnimplementedError(
    'pumpEditorBeta scaffold (M1804). Provider stack to be filled '
    'in iteratively — see the doc comment in '
    'test/features/editor/presentation/pages/_harness/editor_beta_pump.dart '
    'for the inventory + per-handler wiring guide.',
  );
}
