// Test harness entry point used by `flutter_test` automatically (it looks for
// `test/flutter_test_config.dart` and calls its `testExecutable` for every
// test invocation).
//
// We use it to wire alchemist (RULES.md TS-08) with a project-wide config:
//
// - Platform goldens (rendered against the host platform's font/scrollbar/etc.
//   metrics) are disabled — macOS / Linux / Windows would each generate
//   different bytes for the same widget, which makes CI flaky.
// - CI goldens (a deterministic in-process renderer) are enabled, which is
//   what the `flutter test --update-goldens` command updates.
//
// Goldens land under `test/<feature>/goldens/ci/<file>.png`.

import 'dart:async';

import 'package:alchemist/alchemist.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
      ciGoldensConfig: CiGoldensConfig(enabled: true),
    ),
    run: testMain,
  );
}
