# Contributing — Quill (my_notion)

> Policy doc for code style, tests, generated files, and coverage. Read alongside `CLAUDE.md` (project conventions) and `docs/RULES.md` (architectural rules, all severity-classified).

## Quick start

```bash
flutter pub get
flutter analyze              # expects: No issues found
flutter test                 # expects: All tests passed!
dart run custom_lint         # expects: No issues found  (LT-02 / LT-03)
flutter test --coverage      # writes coverage/lcov.info
```

The CI pipeline at `.github/workflows/flutter-ci.yml` runs all four on every push.

## Style baseline

- `package:very_good_analysis/analysis_options.yaml` is the strict baseline (RULES.md **LT-01**).
- `bloc_lint` runs via `custom_lint` for Bloc/Cubit-specific rules (RULES.md **LT-02 / LT-03**).
- `flutter analyze` must be clean before opening a PR. `dart run custom_lint` should also be clean.

## Generated files (RULES.md MD-03)

The drift schema `lib/core/db/quill_database.g.dart` is **generated** by `drift_dev` (`dart run build_runner build`) and **committed** to the repo. Rationale:

- Newcomers can `git clone` + `flutter pub get` + `flutter test` without first running build_runner — a meaningful UX win for review agents and CI alike.
- The schema changes ~once a milestone, so generated-vs-source drift is rare and visible in PR diffs.
- `flutter_clean_arch_bundle/**` and `**/*.g.dart` are `analyzer.exclude`d in `analysis_options.yaml`.

Workflow when editing the schema:

```bash
# 1. Edit lib/core/db/quill_database.dart (drift table definitions)
# 2. Regenerate the .g.dart file
dart run build_runner build --delete-conflicting-outputs
# 3. Commit both files together in the same milestone commit
git add lib/core/db/quill_database.dart lib/core/db/quill_database.g.dart
```

Do NOT hand-edit `*.g.dart` files. If a generated file is missing or stale, run `build_runner` again rather than editing manually.

## Coverage ratchet (RULES.md TS-07 deviation)

`RULES.md` TS-07 defaults the coverage gate to **95%**. This project deliberately runs a **62% ratchet** that climbs over time. The deviation is intentional and documented here per **MD-03**.

### History

The gate started at **50%** at M821 (the first commit with `flutter test --coverage` wired). Each ratchet step requires **two consecutive observations** at or above the next half-percent:

| Gate | Adopted at | Trigger |
|------|------------|---------|
| 50%  | M821       | Baseline (measured 53.9%) |
| 55%  | M900       | Two consecutive measurements ≥ 55.5% |
| 56%  | M934       | Two consecutive ≥ 56.5% |
| 57%  | M956       | ≥ 57.5% |
| 58%  | M981       | ≥ 58.5% |
| 59%  | M1024      | ≥ 59.5% |
| 60%  | M1067      | ≥ 60.5% |
| 61%  | M1110      | ≥ 61.5% |
| 62%  | M1156      | ≥ 62.5% |

The next ratchet (63%) requires two consecutive observations at or above 63.5%. The two-observation rule (introduced at M981) prevents a single flaky run from bumping the gate.

### Why not jump to 95%?

The shortfall is concentrated in two areas:

1. **Widget tests** — Most editor / database / palette widgets are exercised end-to-end via integration-style tests but lack focused widget-test coverage. Each missing widget test would lift coverage by ~0.2-0.5%.
2. **Edge cases in importers** — `lib/features/vault/data/` has CSV / HTML / Markdown / OPML / Roam / Trello / Asana / Evernote / Word importers, each with happy-path tests but few error/malformed-input tests.

The 1m-loop plan at `~/.claude/plans/1m-run-until-we-frolicking-thompson.md` Phase B/C lands new features whose tests will continue the ratchet. The 95% bar is a long-tail goal, not blocking shipping.

### Lowering the gate

The CI never lowers `min_coverage`. If a refactor would temporarily drop coverage below the gate, either:

- Add the missing tests in the same PR, or
- Split the refactor across multiple PRs so each lands with coverage ≥ gate.

## Test tree mirroring (RULES.md TS-01)

Every new file under `lib/<feature>/domain/` or `lib/<feature>/data/` requires a corresponding `test/<feature>/.../<file>_test.dart`. Presentation layer (widgets/pages/blocs) is exempt by convention except blocs themselves — every Bloc/Cubit needs a bloc_test.

When adding a new feature folder (`lib/features/<name>/`):

```
lib/features/<name>/
  data/datasources/<thing>.dart       → test/features/<name>/<thing>_test.dart
  data/repositories/<repo>.dart       → test/features/<name>/<repo>_test.dart
  domain/usecases/<usecase>.dart      → test/features/<name>/<usecase>_test.dart
  presentation/bloc/<name>_bloc.dart  → test/features/<name>/<name>_bloc_test.dart
  presentation/pages/<page>.dart      → (exempt unless behavior-bearing)
```

Use `package:bloc_test/bloc_test.dart` for bloc tests, `package:alchemist/alchemist.dart` for goldens, `package:mockingjay/mockingjay.dart` for router-touching widget tests, `package:mocktail/mocktail.dart` for everything else.

## Architecture review

`docs/RULES.md` is the source of truth for architectural rules. The orchestrator (`flutter-arch-orchestrator` subagent) audits the project against these rules on every milestone gate; findings land in `docs/plans/quill-loop-state.md`.

If a rule's letter-of-the-law severity blocks pragmatic progress, document the deviation here (like TS-07 above) rather than silently violating it.

## Commit message style

Format: `Mxxxx: <short description>`, where `Mxxxx` is a monotonic milestone counter (currently in the **M1200+** range). Examples in `git log --oneline | head -20`.

Co-Authored-By lines for AI-assisted commits use the `Claude Opus 4.7 (1M context) <noreply@anthropic.com>` form.
