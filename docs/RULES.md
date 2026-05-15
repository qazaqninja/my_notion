# Enforceable Rules — Flutter Clean Architecture + Bloc

Each rule has a stable ID, a one-line statement, a rationale, an enforcement mechanism (`static` = lint/regex, `review` = human or agent), and a severity. The review agents in `.claude/agents/` reference these IDs directly.

## Severity legend

- **block** — fails CI; cannot merge.
- **warn** — flagged on review; must be justified in PR description if intentional.
- **info** — discussion point; not blocking.

---

## Layering & dependency direction

### CA-01 — Business logic is pure Dart
**Statement.** Files under any `bloc/` folder (`*_bloc.dart`, `*_cubit.dart`, `*_state.dart`, `*_event.dart`) must not import `package:flutter/*`.
**Rationale.** Keeps the business-logic layer portable and unit-testable without a widget tree. (`bloclibrary.dev/lint-rules/avoid_flutter_imports`)
**Enforcement.** static — `bloc_lint avoid_flutter_imports` + grep regex.
**Severity.** block.

### CA-02 — Repository layer is pure Dart
**Statement.** Files in `packages/*_repository/` must not import `package:flutter/*`.
**Rationale.** Repositories must be reusable across apps and testable as plain Dart packages.
**Enforcement.** static — grep / custom_lint.
**Severity.** block.

### CA-03 — Data layer is pure Dart
**Statement.** Files in `packages/*_api/` (or equivalent data-provider packages) must not import `package:flutter/*`.
**Rationale.** Data providers describe transport, not UI.
**Enforcement.** static — grep / custom_lint.
**Severity.** block.

### CA-04 — Presentation never imports the data layer directly
**Statement.** Files under `lib/<feature>/` must not import any `<x>_api` package. They may only import `<x>_repository` packages.
**Rationale.** Enforces the dependency rule. The bloc talks to repositories, not raw API clients.
**Enforcement.** static — custom_lint (`presentation_no_data_import`).
**Severity.** block.

### CA-05 — DTOs do not cross repository boundary
**Statement.** A repository's public API must not return or expose any class declared in an `_api` package (DTOs). Repositories map DTOs to domain models.
**Rationale.** Caller code reasons about domain shapes, not wire shapes. (`docs.flutter.dev/app-architecture/case-study/data-layer`)
**Enforcement.** review — agent check.
**Severity.** block.

### CA-06 — Blocs do not depend on other blocs
**Statement.** No `*_bloc.dart` or `*_cubit.dart` may import another bloc/cubit from a different feature.
**Rationale.** "No bloc should know about any other bloc. A bloc should only receive information through events and from injected repositories." (`bloclibrary.dev/architecture`)
**Enforcement.** static — custom_lint + grep.
**Severity.** block.

### CA-07 — Dependencies flow downward only
**Statement.** A data provider must not import a repository or any bloc. A repository must not import any bloc.
**Rationale.** The dependency rule. Reverse dependencies break the architecture.
**Enforcement.** static — custom_lint.
**Severity.** block.

---

## Folder structure

### FS-01 — Feature-first
**Statement.** Code in `lib/` is organized by feature, not by layer. No top-level `lib/blocs/`, `lib/repositories/`, `lib/screens/` directories.
**Rationale.** All authoritative samples (VGV, Compass) organize by feature. Layer-first does not scale.
**Enforcement.** review — agent check + lint.
**Severity.** warn.

### FS-02 — One bloc subfolder per feature
**Statement.** A feature with state management has exactly one `bloc/` subfolder containing `<feature>_bloc.dart` (or `_cubit.dart`), `<feature>_event.dart` (bloc only), `<feature>_state.dart`.
**Rationale.** Matches `very_good_core` template.
**Enforcement.** review.
**Severity.** warn.

### FS-03 — Repositories and data providers in `packages/`
**Statement.** Repositories live in `packages/<name>_repository/`. Raw data providers live in `packages/<name>_api/`.
**Rationale.** Makes the dependency rule unforgeable through `pub` (path dependencies cannot cycle).
**Enforcement.** review.
**Severity.** warn.

### FS-04 — Test tree mirrors lib tree
**Statement.** Every file in `lib/` has a corresponding `test/` path. Test directory shape mirrors `lib/`.
**Rationale.** Makes coverage gaps visible at the folder level. (`engineering.verygood.ventures/testing/testing_overview`)
**Enforcement.** static — custom check.
**Severity.** warn.

### FS-05 — Barrel files only export public API
**Statement.** A `<feature>.dart`, `widgets.dart`, or `models.dart` barrel exports only types intended for use outside the folder. Library-private files (e.g., `*_event.dart`) are not exported.
**Rationale.** Encapsulation; prevents accidental dependencies on internals. (`engineering.verygood.ventures/development/architecture/barrel_files`)
**Enforcement.** review.
**Severity.** warn.

---

## Bloc & Cubit

### BL-01 — Default to Cubit
**Statement.** New state managers start as a `Cubit`. Upgrade to `Bloc` only when one of these is true: you need event transformers (debounce/throttle/droppable/restartable/sequential); you need an explicit event log for analytics or debugging; the feature has many discrete user intents whose names carry meaning. Justify the upgrade in a comment at the top of the file.
**Rationale.** `bloclibrary.dev/lint-rules/prefer_cubit`; less boilerplate, less surface area.
**Enforcement.** static — `bloc_lint prefer_cubit`.
**Severity.** warn.

### BL-02 — Event naming
**Statement.** Events are nouns in the past tense (`LoginSubmitted`, `PostsRequested`, `FilterChanged`). Not verbs in the imperative.
**Rationale.** `bloclibrary.dev/naming-conventions`. Events describe what already happened in the UI.
**Enforcement.** review.
**Severity.** warn.

### BL-03 — State naming
**Statement.** States are nouns describing a snapshot (`PostsState`, `LoginState`).
**Rationale.** `bloclibrary.dev/naming-conventions`.
**Enforcement.** review.
**Severity.** warn.

### BL-04 — One state shape pattern per feature
**Statement.** Pick one of: (a) single state class with status enum + nullable fields + `copyWith`, or (b) sealed-class union of state subclasses. Do not mix within a feature.
**Rationale.** `bloclibrary.dev/modeling-state`. Both are valid; mixing them defeats the readability gain.
**Enforcement.** review.
**Severity.** warn.

### BL-05 — Status enum names are stable
**Statement.** When using pattern (a), the status enum has values from this set: `initial`, `loading`, `success`, `failure`. Project-specific additions allowed; renames of these four are not.
**Rationale.** Consistency across features. (`bloclibrary.dev/tutorials/flutter-weather`)
**Enforcement.** static — grep.
**Severity.** warn.

### BL-06 — Value equality is mandatory
**Statement.** Every state and event class extends `Equatable` (or is a `freezed` class). `props` lists every field.
**Rationale.** Prevents redundant rebuilds; required for `bloc_test` `expect` to work.
**Enforcement.** static — custom_lint.
**Severity.** block.

### BL-07 — State and event are immutable
**Statement.** State and event classes use `final` for every field and provide no mutating setters.
**Rationale.** Bloc framework assumes immutability for change detection.
**Enforcement.** static — `prefer_final_fields`, `prefer_const_constructors_in_immutables`.
**Severity.** block.

### BL-08 — No BuildContext in blocs
**Statement.** No `*_bloc.dart` / `*_cubit.dart` file may reference `BuildContext`.
**Rationale.** Couples business logic to widget tree.
**Enforcement.** static — grep.
**Severity.** block.

### BL-09 — No Navigator/go_router calls in blocs
**Statement.** Blocs never call `Navigator.*`, `context.go`, `context.push`, etc. Emit a state; navigate via `BlocListener`.
**Rationale.** CA-01 + navigation is a side effect, not state.
**Enforcement.** static — grep.
**Severity.** block.

### BL-10 — Event transformer specified for non-idempotent events
**Statement.** `on<Event>(handler, transformer: ...)` must specify a transformer when the event handler performs I/O. Defaults to `droppable()` for submit-style events, `restartable()` for search-style events, `sequential()` for ordered writes. The default `concurrent` is acceptable only for pure-read events.
**Rationale.** `engineering.verygood.ventures/development/state_management/bloc_event_transformers`.
**Enforcement.** review.
**Severity.** warn.

### BL-11 — `BlocListener` for side effects, `BlocBuilder` for UI
**Statement.** `BlocListener` is the only place for navigation, snackbars, dialogs, analytics. `BlocBuilder` only renders UI. `BlocConsumer` is used only when the same state truly drives both.
**Rationale.** `bloclibrary.dev/flutter-bloc-concepts`.
**Enforcement.** review.
**Severity.** warn.

### BL-12 — `buildWhen` / `listenWhen` for performance
**Statement.** When a builder or listener only cares about a subset of state, use `buildWhen` / `listenWhen` to skip unrelated emissions.
**Rationale.** Prevents needless rebuilds.
**Enforcement.** review.
**Severity.** info.

---

## Repositories & data layer

### RP-01 — One repository per domain
**Statement.** A repository owns exactly one domain (`WeatherRepository`, `AuthRepository`). Two unrelated domains in the same class is a smell.
**Rationale.** `bloclibrary.dev/architecture`.
**Enforcement.** review.
**Severity.** warn.

### RP-02 — Constructor injection
**Statement.** Every dependency (API clients, other repositories, key-value stores) is passed to the constructor as a named parameter. No `static`/global lookups, no service locator inside the repository body.
**Rationale.** Testability + dependency rule.
**Enforcement.** review.
**Severity.** block.

### RP-03 — Typed exceptions at the boundary
**Statement.** A repository never lets `dart:io` or framework exceptions leak. It catches and either rethrows a typed domain exception (extending `Exception`) or returns a failure state shape.
**Rationale.** §8 of the reference doc.
**Enforcement.** review.
**Severity.** warn.

### DP-01 — Data providers expose DTOs
**Statement.** Methods on an `_api` class return either DTOs or `Future<DTO>` / `Stream<DTO>`. They never return a domain model.
**Rationale.** Mapping happens in the repository, not below it.
**Enforcement.** review.
**Severity.** warn.

### DP-02 — Data providers throw narrow exceptions
**Statement.** Each `_api` class defines its own exception types (e.g., `WeatherRequestFailure`, `WeatherNotFoundFailure`) and throws those, not generic `Exception`.
**Rationale.** Lets the repository discriminate.
**Enforcement.** review.
**Severity.** warn.

---

## Dependency injection

### DI-01 — Use RepositoryProvider / BlocProvider, not service locators
**Statement.** Repositories are exposed via `RepositoryProvider` / `MultiRepositoryProvider` at the top of the widget tree. Blocs are exposed via `BlocProvider` scoped to their consuming subtree. `get_it`, `injectable`, and `kiwi` are not used.
**Rationale.** All three authoritative sources recommend widget-tree DI (`docs.flutter.dev/app-architecture/case-study/dependency-injection`, `bloclibrary.dev/flutter-bloc-concepts`, `very_good_core`).
**Enforcement.** static — pubspec grep + custom_lint.
**Severity.** block.

### DI-02 — Repositories above blocs
**Statement.** In the widget-tree DI graph, `RepositoryProvider`s are always ancestors of `BlocProvider`s that consume them.
**Rationale.** Blocs read repositories from context; reverse is impossible.
**Enforcement.** review.
**Severity.** warn.

### DI-03 — Feature blocs scoped to their route
**Statement.** A bloc used by exactly one feature is provided inside that feature's route `builder`, not at the root.
**Rationale.** Disposal correctness + avoids global state.
**Enforcement.** review.
**Severity.** warn.

### DI-04 — `context.read` for one-shot, `context.watch` / `BlocBuilder` for subscription
**Statement.** Inside `build`, never call `context.read<T>()` for a value the widget should rebuild on — use `BlocBuilder` or `context.watch`. Inside callbacks (`onPressed`), use `context.read`.
**Rationale.** Avoids subtle rebuild bugs.
**Enforcement.** static — `flutter_bloc` lint.
**Severity.** warn.

---

## Models & code generation

### MD-01 — DTO ≠ domain model ≠ state
**Statement.** Three distinct types: DTO (in `_api` package), domain model (in `_repository` package), feature state (in `lib/<feature>/bloc/`). Don't reuse one class across layers.
**Rationale.** §7 of the reference doc.
**Enforcement.** review.
**Severity.** warn.

### MD-02 — Pick one code-gen tool, project-wide
**Statement.** A repo uses either plain Dart + `json_serializable` OR `freezed` + `json_serializable`. Not both.
**Rationale.** Consistency. Both are authoritative-source-acceptable.
**Enforcement.** review.
**Severity.** warn.

### MD-03 — Generated files policy
**Statement.** Generated `*.g.dart` and `*.freezed.dart` files are either committed (the default) OR generated in CI. The repo's CONTRIBUTING.md states which.
**Rationale.** Avoids merge conflicts and ambiguous CI failures.
**Enforcement.** review.
**Severity.** info.

### MD-04 — `invalid_annotation_target: ignore` if using freezed + json_serializable
**Statement.** `analysis_options.yaml` must set this when both `freezed` and `json_serializable` are dependencies.
**Rationale.** Combo otherwise emits a warning on every freezed class. Documented in `pub.dev/packages/freezed`.
**Enforcement.** static.
**Severity.** info.

---

## Testing

### TS-01 — Test tree mirrors lib tree
**Statement.** Every `lib/path/file.dart` has either `test/path/file_test.dart` or a documented exemption. (See FS-04.)
**Enforcement.** static.
**Severity.** warn.

### TS-02 — `mocktail`, not `mockito`
**Statement.** `pubspec.yaml`'s `dev_dependencies` includes `mocktail` and does not include `mockito`.
**Rationale.** `bloclibrary.dev/testing`, VGV standard.
**Enforcement.** static — pubspec grep.
**Severity.** block.

### TS-03 — Bloc tests use `bloc_test`
**Statement.** Tests for any `Bloc`/`Cubit` use `blocTest<BlocType, StateType>(...)` rather than manually subscribing to the stream.
**Rationale.** `bloclibrary.dev/testing`.
**Enforcement.** review.
**Severity.** warn.

### TS-04 — Bloc tests grouped by event/method name
**Statement.** Each bloc test file has top-level `group` blocks named after the event (Bloc) or method (Cubit) under test.
**Rationale.** VGV convention.
**Enforcement.** review.
**Severity.** info.

### TS-05 — Private mocks per test file
**Statement.** Mocks are declared at the bottom of the test file with `class _MockX extends Mock implements X {}`. No shared `MockX` exported from `test/helpers/` for use across many test files.
**Rationale.** Avoids cross-test contamination.
**Enforcement.** review.
**Severity.** warn.

### TS-06 — Widget tests verify behavior
**Statement.** Widget tests `tap`, `enterText`, `pumpAndSettle`, and assert on resulting state — they don't assert on private widget properties.
**Rationale.** VGV testing handbook.
**Enforcement.** review.
**Severity.** warn.

### TS-07 — Coverage gate
**Statement.** CI fails if line coverage drops below the project's threshold (default 95%). Use `very_good_coverage` action or `lcov_check`.
**Rationale.** `engineering.verygood.ventures/testing/testing_overview`.
**Enforcement.** static — CI.
**Severity.** block.

### TS-08 — Goldens with `alchemist`, not raw `matchesGoldenFile`
**Statement.** For visual regression of widgets, use `alchemist` golden groups, which handle platform-font normalization.
**Rationale.** `verygood.ventures/blog/alchemist-golden-tests-tutorial`.
**Enforcement.** review.
**Severity.** info.

### TS-09 — go_router mocked with `mockingjay`
**Statement.** Navigation tests on widgets that use `go_router` use `MockGoRouter` from `mockingjay`.
**Rationale.** `verygood.ventures/blog/mocking-flutter-routes-with-mockingjay`.
**Enforcement.** review.
**Severity.** info.

---

## Navigation

### NV-01 — Use go_router
**Statement.** `pubspec.yaml` declares `go_router` as the routing dependency. No `auto_route`, `flutter_modular`, etc.
**Rationale.** `docs.flutter.dev/ui/navigation` recommends `go_router`.
**Enforcement.** static — pubspec grep.
**Severity.** warn.

### NV-02 — Prefer typed routes
**Statement.** Routes are defined via typed `go_router` route builders (`TypedGoRoute`) when the route takes parameters.
**Rationale.** `engineering.verygood.ventures/development/ui/navigation`. Eliminates typo and casting bugs.
**Enforcement.** review.
**Severity.** warn.

### NV-03 — Prefer `go` over `push`
**Statement.** `context.go(...)` is the default. `context.push(...)` is used only when the user must be able to return to the current screen via the back button.
**Rationale.** VGV. Push-stack growth causes back-button drift.
**Enforcement.** review.
**Severity.** info.

### NV-04 — Shell nesting capped at two
**Statement.** No more than two nested `ShellRoute`s. Three or more is a UX red flag.
**Rationale.** VGV.
**Enforcement.** review.
**Severity.** warn.

---

## Theming

### TH-01 — `useMaterial3: true`
**Statement.** Every `ThemeData(...)` sets `useMaterial3: true`.
**Rationale.** Default since the M3 migration; setting it explicitly documents intent.
**Enforcement.** static — grep.
**Severity.** info.

### TH-02 — `ColorScheme.fromSeed`
**Statement.** Light and dark themes are derived from a single seed color via `ColorScheme.fromSeed`.
**Rationale.** `api.flutter.dev/.../ColorScheme.fromSeed`.
**Enforcement.** review.
**Severity.** info.

### TH-03 — No hard-coded colors in widgets
**Statement.** Widgets read colors from `Theme.of(context).colorScheme.*` or a `ThemeExtension`. Hex literals (`Color(0xFF...)`) inside widget files are flagged.
**Rationale.** Dark-mode support; design-token consistency.
**Enforcement.** static — custom_lint `no_color_literals_in_widgets`.
**Severity.** warn.

### TH-04 — Design tokens via `ThemeExtension`
**Statement.** Spacing, radii, shadows, and brand colors that aren't part of `ColorScheme` live in a `ThemeExtension<T>` subclass.
**Rationale.** `api.flutter.dev/.../ThemeExtension`.
**Enforcement.** review.
**Severity.** info.

---

## Linting

### LT-01 — `very_good_analysis` baseline
**Statement.** `analysis_options.yaml` includes `package:very_good_analysis/analysis_options.yaml`.
**Enforcement.** static — file check.
**Severity.** block.

### LT-02 — `bloc_lint` enabled
**Statement.** `bloc_lint` is configured and runs in CI.
**Enforcement.** static — CI step.
**Severity.** block.

### LT-03 — `custom_lint` runs project-specific rules
**Statement.** `dart run custom_lint` is part of the CI pipeline.
**Enforcement.** static — CI step.
**Severity.** block.

---

## How agents use this file

The agents in `.claude/agents/` reference rule IDs (`CA-01`, `BL-04`, etc.) in their findings. A finding looks like:

> `lib/auth/bloc/auth_bloc.dart:12` — **BL-08 (block)** Bloc references `BuildContext`. Move the navigation side effect to a `BlocListener` in the parent widget.

This format lets you scan the violations list and look up the rule's rationale in this file.
