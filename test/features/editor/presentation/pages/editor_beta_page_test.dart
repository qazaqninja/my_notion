import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/features/editor/presentation/pages/editor_beta_page.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';

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
    });
  });
}
