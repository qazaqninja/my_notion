import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/features/editor/domain/repositories/html_export_repository.dart';
import 'package:my_notion/features/editor/domain/repositories/pdf_export_repository.dart';
import 'package:my_notion/features/editor/presentation/pages/editor_beta_page.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';

import '_harness/editor_beta_pump.dart';

void main() {
  // M1787 (TS-01 stub): minimal smoke test for EditorBetaPage. The
  // 26+ D-fp `_on…` async handlers in this file are all
  // `coverage:ignore-start/end`-exempt per M1571 because their
  // widget-tier orchestration (SnackBar / showDialog / FilePicker /
  // Clipboard) requires a full BlocProvider + RepositoryProvider +
  // GoRouter stack to mount. This stub establishes the test-file
  // scaffold so future per-handler tests have a landing surface +
  // gives lcov a coverage target on the public constructor.
  //
  // Per-handler smoke tests are deferred until a dedicated
  // editor_beta_page widget-test sweep (next-after-this slice) can
  // build the provider harness once and reuse it across cases.
  // M1788 fix-forward: dropped the structural `isNot` duplicate
  // assert per the M1787 audit's TS-06 WARN. Single stub assert
  // here is intentionally narrow — behavioral per-handler tests
  // (mount → tap kebab → assert dispatch) land once the shared
  // provider harness is built in the next slice.
  group('EditorBetaPage', () {
    group('public construction surface', () {
      test('accepts `ulid` and is a StatelessWidget', () {
        const page = EditorBetaPage(ulid: '01H0000000000000000000ABCD');

        expect(page.ulid, '01H0000000000000000000ABCD');
        expect(page, isA<StatelessWidget>());
      });
    });

    // M1804/M1806: pumpEditorBeta scaffold in _harness/editor_beta_pump.dart.
    // Sub-slice 2 (M1806) wired the 3 foundation providers
    // (VaultRepository + Indexer + QuillDatabase) via in-memory fakes.
    // Subsequent sub-slices add the remaining 6 collaborators + swap the
    // probe for EditorBetaPage itself.
    //
    // TS-06 acceptance note: this probe test verifies *wiring* (DI
    // resolution), not behavior. When per-handler slices swap the
    // probe for `EditorBetaPage`, they must shift to behavioral
    // assertions (tap → assert dispatch) per TS-06.
    group('shared pump harness foundations', () {
      testWidgets('mounts MultiRepositoryProvider with VaultRepository + '
          'Indexer + QuillDatabase resolvable via context.read',
          (tester) async {
        late VaultRepository foundRepo;
        late Indexer foundIndexer;
        late QuillDatabase foundDb;

        final harness = await pumpEditorBeta(
          tester,
          ulid: '01H0000000000000000000ABCD',
          probe: Builder(
            builder: (context) {
              foundRepo = context.read<VaultRepository>();
              foundIndexer = context.read<Indexer>();
              foundDb = context.read<QuillDatabase>();
              return const SizedBox.shrink();
            },
          ),
        );
        addTearDown(harness.dispose);

        expect(foundRepo, isA<VaultRepository>());
        expect(foundIndexer, isA<Indexer>());
        expect(foundDb, isA<QuillDatabase>());
      });

      // M1809 sub-slice 3: HtmlExportRepository + PdfExportRepository +
      // FormsRepository also resolvable now. Per-handler slices that
      // need richer FormsRepository behavior can wrap their own
      // RepositoryProvider override around the call site.
      testWidgets(
          'mounts ExportRepository pair + FormsRepository (no-op stub)',
          (tester) async {
        late HtmlExportRepository foundHtml;
        late PdfExportRepository foundPdf;
        late FormsRepository foundForms;

        final harness = await pumpEditorBeta(
          tester,
          ulid: '01H0000000000000000000ABCD',
          probe: Builder(
            builder: (context) {
              foundHtml = context.read<HtmlExportRepository>();
              foundPdf = context.read<PdfExportRepository>();
              foundForms = context.read<FormsRepository>();
              return const SizedBox.shrink();
            },
          ),
        );
        addTearDown(harness.dispose);

        expect(foundHtml, isA<HtmlExportRepository>());
        expect(foundPdf, isA<PdfExportRepository>());
        expect(foundForms, isA<FormsRepository>());
        // The no-op stub returns an empty list for any (token, ulid).
        await expectLater(
          foundForms.listSubmissions(token: 't', ulid: 'u'),
          completion(isEmpty),
        );
      });

      // M1813 sub-slice 5 FINAL: default probe is now the real
      // `EditorBetaPage(ulid: ...)` wrapped in `MaterialApp.router`.
      // This first behavioral smoke test verifies the page mounts
      // without throwing — promotes the M1811 scaffold-only probes
      // into a real widget test per the M1811 TS-03 forward note.
      testWidgets('default probe mounts EditorBetaPage without throwing',
          (tester) async {
        final harness = await pumpEditorBeta(
          tester,
          ulid: '01H0000000000000000000ABCD',
        );
        addTearDown(harness.dispose);
        // Let any post-mount async work (EditorBloc OpenEditor →
        // indexer lookup → state emit) settle before asserting.
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(EditorBetaPage), findsOneWidget);
      });

      // M1811 sub-slice 4: VaultBloc + SyncBloc resolvable via
      // bloc_test MockBloc stubs (no-op initial state). 8 of 9
      // collaborators wired after this slice.
      // M1820 sub-slice 6: pumpEditorBeta now takes an optional
      // `seedPage` parameter that:
      //   (a) writes one `.md` file to the in-memory
      //       MemoryFileSystem at `<rootPath>/page.md` with
      //       `id: <ulid>` + `title: <seedTitle>` frontmatter,
      //   (b) runs `indexer.reindex(rootDir)` so the in-memory
      //       drift db gets the page row,
      //   (c) `whenListen`s the existing `_StubVaultBloc` into
      //       `VaultLoaded(rootPath:, tree:, expandedFolders:,
      //       pageCount: 1)` so editor handlers that early-return
      //       on `vaultState is VaultLoaded` see a loaded vault.
      //
      // This probe-style test exercises the seed path without
      // mounting the real `EditorBetaPage`. A follow-on slice
      // will swap the probe for the page itself + tap the kebab,
      // but that path currently trips super_editor's
      // pumpAndSettle on the empty-document layout (see the
      // multi-exception trace in the M1820 attempt). Splitting
      // the harness-seed deliverable from the kebab-interaction
      // test keeps each slice bite-sized + lands the seedPage
      // primitive that per-handler smokes need.
      group('seedPage:true', () {
        testWidgets('writes the page to drift + emits VaultLoaded',
            (tester) async {
          const ulid = '01H0000000000000000000ABCD';
          final harness = await pumpEditorBeta(
            tester,
            ulid: ulid,
            seedPage: true,
            seedTitle: 'Seeded',
            probe: const SizedBox.shrink(),
          );
          addTearDown(harness.dispose);

          final pages = await harness.db.select(harness.db.pages).get();
          expect(pages.map((p) => p.ulid), [ulid]);
          expect(pages.single.title, 'Seeded');
          expect(harness.vaultBloc.state, isA<VaultLoaded>());
        });

        // M1823 sub-slice 7: real-page mount with seedPage:true.
        // The M1820 attempt to mount `EditorBetaPage` (default
        // probe) against a seeded page hit "Multiple exceptions
        // (10)" during pumpAndSettle on super_editor's empty-body
        // layout in the default 800×600 flutter_test surface
        // (~267×200 logical). The block-reorder / find-in-page /
        // slash-menu keyboard actions all attach overlays that
        // need real estate to position, and the SuperEditor
        // documentLayout falls back to its own size-zero path
        // when the viewport is too small — which throws inside
        // its render-object during the first paint pass.
        //
        // Fix: bump the test surface to 1200×900 logical so
        // super_editor's overlays + scrollable have room. Use
        // `tester.view.physicalSize` + reset via tearDown to
        // avoid leaking the larger size into the rest of the
        // suite. Pump a handful of frames (no pumpAndSettle —
        // pending overlay animations could still log advisory
        // exceptions per the M1820 trace), then assert the
        // kebab (`More actions` tooltip) is findable.
        //
        // This unblocks the M1818 stub group's `_onCopyUlid`
        // per-handler smoke as the next slice — once the kebab
        // is reachable, the tap → assert clipboard interaction
        // is mechanical.
        testWidgets('real-page mount with surface 1200×900 → kebab visible',
            (tester) async {
          tester.view.physicalSize = const Size(1200, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const ulid = '01H0000000000000000000ABCD';
          final harness = await pumpEditorBeta(
            tester,
            ulid: ulid,
            seedPage: true,
          );
          addTearDown(harness.dispose);
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }

          expect(find.byTooltip('More actions'), findsOneWidget);
        });
      });

      // M1826 — first per-handler smoke test using the full mount
      // path the harness arc has been building toward
      // (M1804→M1813→M1820→M1823). The M1817 spike attempted this
      // test before the harness reached EditorLoaded; the M1818
      // fix-forward wrapped the empty stub in a group so the
      // landing site stayed visible. With M1823 wiring QuillTokens
      // into _defaultProbe and M1820's seedPage:true reaching
      // EditorLoaded, the full mount → tap kebab → tap "Copy ULID"
      // → assert clipboard chain runs.
      //
      // Pattern: mock SystemChannels.platform method-call handler
      // intercepts `Clipboard.setData` and captures the `text` arg.
      // After tapping the kebab and the menu item, the captured
      // text must equal the seeded ulid. This is the per-handler
      // contract for the entire D-fp arc's 26 kebab handlers —
      // future slices reuse this exact shape for _onCopyLink,
      // _onCopyPath, _onCopyBody, _onCopyPlain, _onCopyJson, etc.
      // (TS-04 per-handler grouping per orchestrator INFO M1823.)
      group('_onCopyUlid (D-fp6, M1703) — per-handler smoke', () {
        testWidgets('tap kebab → Copy ULID → clipboard receives ulid',
            (tester) async {
          tester.view.physicalSize = const Size(1200, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          String? clipboardText;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardText =
                    (call.arguments as Map<Object?, Object?>)['text']
                        as String?;
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );

          const ulid = '01H0000000000000000000ABCD';
          final harness = await pumpEditorBeta(
            tester,
            ulid: ulid,
            seedPage: true,
          );
          addTearDown(harness.dispose);
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }

          await tester.tap(find.byTooltip('More actions'));
          // Pump enough frames for the PopupMenu to open without
          // triggering pumpAndSettle's pending-animation noise.
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          // M1827 fix-forward: the production `PopupMenuItem` Row
          // now wraps its `Text` child in
          // `Expanded(..., overflow: TextOverflow.ellipsis)` so the
          // popup no longer overflows the Material ~256px max width
          // under flutter_test's Ahem font. Per orchestrator M1826
          // TS-06: tighter `isNull` assert replaces the previous
          // drain loop; future per-handler tests inherit this shape
          // so genuine exceptions can't be silently swallowed.
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Copy ULID'));
          await tester.pump();
          expect(tester.takeException(), isNull);

          expect(clipboardText, ulid);
        });
      });

      testWidgets('mounts VaultBloc + SyncBloc stubs (no-op initial state)',
          (tester) async {
        late VaultBloc foundVault;
        late SyncBloc foundSync;

        final harness = await pumpEditorBeta(
          tester,
          ulid: '01H0000000000000000000ABCD',
          probe: Builder(
            builder: (context) {
              foundVault = context.read<VaultBloc>();
              foundSync = context.read<SyncBloc>();
              return const SizedBox.shrink();
            },
          ),
        );
        addTearDown(harness.dispose);

        expect(foundVault, isA<VaultBloc>());
        expect(foundSync, isA<SyncBloc>());
        // Both stubs start at their canonical "no work done yet"
        // state — matches what the editor handlers' early-return
        // guards check for.
        expect(foundSync.state.isAuthed, isFalse);
      });
    });
  });
}
