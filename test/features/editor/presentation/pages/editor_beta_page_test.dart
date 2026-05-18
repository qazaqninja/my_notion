import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/pages/editor_beta_page.dart';

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

    // M1804: pumpEditorBeta scaffold landed in
    // _harness/editor_beta_pump.dart. The helper currently throws
    // UnimplementedError — per-collaborator wiring follows in
    // successive slices. This meta-test asserts the helper is
    // wired into the test file (`import` resolves) so future
    // slices know where to extend.
    group('shared pump harness scaffold', () {
      testWidgets('pumpEditorBeta throws UnimplementedError until wired',
          (tester) async {
        await expectLater(
          pumpEditorBeta(tester, ulid: '01H0000000000000000000ABCD'),
          throwsUnimplementedError,
        );
      });
    });
  });
}
