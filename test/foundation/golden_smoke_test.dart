// Smoke golden test for alchemist (RULES.md TS-08).
//
// Verifies that alchemist's `goldenTest` driver renders deterministic widgets
// and matches the generated golden file. Once this passes, the architectural
// prerequisite for goldening real Quill widgets (chips, page header, frozen
// table cells) is satisfied.
//
// Goldens are generated once via `flutter test --update-goldens
// test/foundation/golden_smoke_test.dart` and re-verified on every CI run.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

void main() {
  goldenTest(
    'alchemist smoke — colored squares (TS-08)',
    fileName: 'golden_smoke_squares',
    builder: () => GoldenTestGroup(
      scenarioConstraints: const BoxConstraints.tightFor(
        width: 120,
        height: 120,
      ),
      children: [
        GoldenTestScenario(
          name: 'red',
          child: Container(
            width: 100,
            height: 100,
            color: const Color(0xFFFF0000),
          ),
        ),
        GoldenTestScenario(
          name: 'blue',
          child: Container(
            width: 100,
            height: 100,
            color: const Color(0xFF0000FF),
          ),
        ),
      ],
    ),
  );
}
