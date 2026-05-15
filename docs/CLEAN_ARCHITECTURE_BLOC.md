# Clean Architecture for Flutter with Bloc — Authoritative Reference

> **Source filter.** Every recommendation in this document is traceable to one of the following: official Flutter/Dart docs (`docs.flutter.dev`, `api.flutter.dev`), the official Bloc library docs (`bloclibrary.dev`) by Felix Angelov, Very Good Ventures (`verygood.ventures`, `engineering.verygood.ventures`) — Google's preferred Flutter consultancy and publisher of `very_good_analysis`, `very_good_cli`, `mocktail`, and `bloc` co-maintenance, the official Flutter samples repo (`github.com/flutter/samples`), and the Material 3 Flutter guidelines (`m3.material.io/develop/flutter`). Where these sources disagree, the disagreement is called out explicitly.

---

## Table of contents

1. The architecture in one diagram
2. Layers and the dependency rule
3. Folder structure (feature-first)
4. The presentation layer: Bloc vs Cubit
5. The repository layer
6. The data layer
7. Entities, models, DTOs
8. Error handling
9. Dependency injection
10. Testing
11. Code generation
12. Navigation with go_router
13. Theming with Material 3
14. Modularization with melos
15. Linting baseline
16. Areas where authoritative sources disagree

---

## 1. The architecture in one diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                            │
│   Widgets (View)  ───────►  Bloc / Cubit  ───────►  emits State       │
│       ▲                          │                                    │
│       │  rebuilds on state       │  add events / call methods         │
└───────┼──────────────────────────┼────────────────────────────────────┘
        │                          │ depends on (constructor-injected)
        │                          ▼
┌───────┼──────────────────────────────────────────────────────────────┐
│       │                  REPOSITORY LAYER                             │
│       │     One repository per domain. Combines data sources,         │
│       │     applies business rules, exposes domain models.            │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ depends on
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          DATA LAYER                                   │
│   API clients, platform channels, local DBs, caches. Raw I/O only.    │
└──────────────────────────────────────────────────────────────────────┘
```

Data flows **upward** (data → repository → bloc → widget). Events flow **downward** (widget → bloc → repository). Every layer depends only on the layer directly below it. See `bloclibrary.dev/architecture` and `docs.flutter.dev/app-architecture/concepts`.

**Single source of truth.** "Data changes always happen in the SSOT, which is the data layer" (`docs.flutter.dev/app-architecture/concepts`). The UI never mutates state in place — it dispatches an event and re-renders from the new state the bloc emits.

---

## 2. Layers and the dependency rule

The three authoritative sources describe the same layered architecture with slightly different chunking:

| Source | Layers |
|---|---|
| Flutter team (`docs.flutter.dev/app-architecture`) | UI · (optional domain) · Data |
| Bloc library (`bloclibrary.dev/architecture`) | Presentation · Business Logic · Data (= Repository + Data Provider) |
| Very Good Ventures (`engineering.verygood.ventures/architecture`) | Presentation · Business Logic · Repository · Data |

These are the same layers split differently. The invariants every source agrees on:

- **Dependency direction is downward only.** Presentation depends on Business Logic. Business Logic depends on Repositories. Repositories depend on Data Sources. Nothing reaches back up.
- **The Data layer is the single source of truth.** Caches and in-memory copies higher up are derived state, not authoritative state.
- **Business Logic does not depend on Flutter.** Blocs and Cubits are pure Dart. The `avoid_flutter_imports` rule in `bloc_lint` (`bloclibrary.dev/lint-rules/avoid_flutter_imports`) enforces this mechanically.
- **No bloc knows about any other bloc.** From `bloclibrary.dev/architecture`: "A bloc should only receive information through events and from injected repositories." Cross-bloc communication is solved by pushing the concern up to the presentation layer (a parent widget listens to one bloc and dispatches into another via `BlocListener`) or down to the domain layer (extract a shared repository).

---

## 3. Folder structure (feature-first)

Authoritative sources converge on **feature-first** organization. Layer-first (`lib/screens/`, `lib/blocs/`, `lib/repositories/`) is not endorsed by any of them.

VGV's canonical layout (`engineering.verygood.ventures/architecture`, `github.com/VeryGoodOpenSource/very_good_core`):

```
my_app/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── app/                          # App bootstrap, MaterialApp, theme
│   │   ├── app.dart
│   │   └── view/
│   ├── bootstrap.dart                # runZonedGuarded + Bloc.observer
│   ├── main_development.dart         # flavor entrypoints
│   ├── main_staging.dart
│   ├── main_production.dart
│   └── <feature>/                    # one folder per feature
│       ├── bloc/
│       │   ├── <feature>_bloc.dart   # or _cubit.dart
│       │   ├── <feature>_event.dart  # bloc only
│       │   └── <feature>_state.dart
│       ├── view/
│       │   ├── <feature>_page.dart   # wires up BlocProvider, builds Page
│       │   ├── <feature>_view.dart   # the View widget; consumes bloc
│       │   └── view.dart             # barrel
│       ├── widgets/                  # feature-private widgets
│       │   └── widgets.dart          # barrel
│       └── <feature>.dart            # public barrel for the feature
├── packages/
│   ├── <name>_api/                   # raw data provider (HTTP, platform)
│   ├── <name>_repository/            # repository wrapping the api package
│   └── ui_kit/                       # optional shared UI primitives
├── test/                             # mirrors lib/
└── integration_test/
```

**Rules of thumb for the folder shape:**

- One `bloc/` per feature. The feature directory is the unit of cohesion.
- Repositories and data providers live in `packages/` as standalone Dart packages, not under `lib/`. This makes the dependency rule unforgeable: `lib/` can depend on `packages/<x>_repository`, but `packages/<x>_repository` cannot depend back on `lib/` because that would be a circular path dependency `pub` will refuse.
- Use **barrel files** (`feature.dart`, `widgets.dart`) to expose only the public API of a folder. Library-private files are not exported (`engineering.verygood.ventures/development/architecture/barrel_files`).
- The `test/` tree mirrors `lib/` 1:1.

---

## 4. The presentation layer: Bloc vs Cubit

### When to pick which

From `bloclibrary.dev/faqs` and `bloclibrary.dev/why-bloc`:

- **Default to Cubit** for simple business logic where each user intent maps cleanly to a method call. A `prefer_cubit` lint rule exists in `bloc_lint` (`bloclibrary.dev/lint-rules/prefer_cubit`).
- **Reach for Bloc** when you need any of: an explicit, traceable event log (analytics/debugging); event transformers (debounce / throttle / restartable / droppable / sequential); multiple discrete user intents whose names carry meaning.

### Naming

From `bloclibrary.dev/naming-conventions`:

- Events are nouns in the **past tense** describing what happened in the UI: `LoginSubmitted`, `PostsRequested`, `FilterChanged`. Files: `<feature>_event.dart`.
- States are nouns describing a **snapshot**: `LoginState`, `PostsState`. Files: `<feature>_state.dart`.
- The Bloc/Cubit itself: `LoginBloc`, `PostsCubit`. Files: `<feature>_bloc.dart` / `<feature>_cubit.dart`.

### State shape — pick one of two patterns

Both are explicitly endorsed by `bloclibrary.dev/modeling-state` and `engineering.verygood.ventures/state_management/state_handling`. Pick based on the data, not preference.

**Pattern A — single class with a status enum.** Use when the state carries data that should *survive* error or loading transitions (e.g., a list of posts you still want to render while a refresh is in flight).

```dart
enum PostsStatus { initial, loading, success, failure }

class PostsState extends Equatable {
  const PostsState({
    this.status = PostsStatus.initial,
    this.posts = const <Post>[],
    this.hasReachedMax = false,
    this.errorMessage,
  });

  final PostsStatus status;
  final List<Post> posts;
  final bool hasReachedMax;
  final String? errorMessage;

  PostsState copyWith({
    PostsStatus? status,
    List<Post>? posts,
    bool? hasReachedMax,
    String? errorMessage,
  }) {
    return PostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, posts, hasReachedMax, errorMessage];
}
```

**Pattern B — sealed union of state subclasses.** Use when each state genuinely has different fields and no data needs to survive transitions.

```dart
sealed class WeatherState extends Equatable {
  const WeatherState();
  @override List<Object?> get props => const [];
}

final class WeatherInitial extends WeatherState {
  const WeatherInitial();
}
final class WeatherLoading extends WeatherState {
  const WeatherLoading();
}
final class WeatherLoaded extends WeatherState {
  const WeatherLoaded(this.weather);
  final Weather weather;
  @override List<Object?> get props => [weather];
}
final class WeatherFailure extends WeatherState {
  const WeatherFailure(this.error);
  final String error;
  @override List<Object?> get props => [error];
}
```

Both patterns require value equality (`Equatable` or `freezed`) so the bloc framework can short-circuit identical re-emissions. The Bloc Weather tutorial pins `Equatable` as the canonical choice.

### Event handlers and transformers

`on<Event>(handler, transformer: ...)` from `package:bloc_concurrency` (`bloclibrary.dev`, `engineering.verygood.ventures/development/state_management/bloc_event_transformers`):

| Transformer | When |
|---|---|
| `concurrent` (default) | Independent events; ordering doesn't matter. |
| `sequential()` | Events that mutate the same data and must be applied FIFO. |
| `droppable()` | Submit-style buttons — drop a new tap while one is in flight. |
| `restartable()` | Search-as-you-type — cancel the previous fetch when a new one starts. |

### Side effects: `BlocListener`

`BlocListener` is for side effects that should fire once per state change — navigation, snackbars, dialogs, analytics. `BlocBuilder` is for rebuilding UI from state. `BlocConsumer` combines both when you genuinely need both for the same state stream (`bloclibrary.dev/flutter-bloc-concepts`).

### What blocs must NOT do

- Import `package:flutter/*`. The business-logic layer is pure Dart. Enforced by `bloc_lint`'s `avoid_flutter_imports`.
- Hold a `BuildContext`.
- Call `Navigator` / `context.go`. Emit a state; let the View react via `BlocListener`.
- Call into another bloc.
- Hold mutable state outside of `state`. Every mutation goes through `emit`.

---

## 5. The repository layer

From `bloclibrary.dev/architecture`: "Each repository generally manages a single domain." From `docs.flutter.dev/app-architecture/case-study/data-layer`: "Repositories are the source of truth for model data and translate raw service data into domain models."

A repository:

- Owns one domain (e.g., `WeatherRepository`, `AuthRepository`, `BookingRepository`).
- Depends on one or more **data sources / API clients**, each injected via the constructor.
- Combines them, applies business rules and caching, and translates raw transport types into **domain models**.
- Exposes a small, intention-revealing API to the business-logic layer.
- Catches infrastructure exceptions at the boundary and rethrows typed domain exceptions (see §8).
- Is published as a Dart package in `packages/<name>_repository/` so it has no path back to the app.

```dart
class WeatherRepository {
  WeatherRepository({required WeatherApiClient apiClient})
      : _apiClient = apiClient;

  final WeatherApiClient _apiClient;

  Future<Weather> getWeather(String city) async {
    final dto = await _apiClient.fetchWeather(city); // throws WeatherApiException
    return Weather(
      location: dto.name,
      temperature: dto.main.temp,
      condition: _mapCondition(dto.weather.first.id),
    );
  }
}
```

The repository **never** returns a DTO. The bloc **never** sees a DTO.

---

## 6. The data layer

Data providers — sometimes called API clients or services in the Flutter team docs — are the only layer allowed to touch HTTP, platform channels, files, or databases.

- They expose `Future<Dto>` or `Stream<Dto>` returning the raw transport shape.
- They throw narrow, typed exceptions (`WeatherApiException`, `NetworkException`) — never letting `dart:io` `SocketException` or framework exceptions leak upward.
- They do not depend on the bloc library, Flutter widgets, or any business rule.
- They live in `packages/<name>_api/` and can be reused across apps.

```dart
class WeatherApiClient {
  WeatherApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const _baseUrl = 'api.openweathermap.org';
  final http.Client _httpClient;

  Future<WeatherDto> fetchWeather(String city) async {
    final uri = Uri.https(_baseUrl, '/data/2.5/weather', {'q': city});
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw WeatherRequestFailure();
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherDto.fromJson(json);
  }
}
```

---

## 7. Entities, models, DTOs

Three distinct types of data class, one per layer:

| Type | Lives in | Purpose | Mutability | Shape |
|---|---|---|---|---|
| **DTO** (Data Transfer Object) | `packages/<x>_api/` | Mirrors the wire format | Immutable | Matches the API exactly, including ugly field names |
| **Domain model** | `packages/<x>_repository/` | The business object the app reasons about | Immutable | Clean field names, computed accessors, no JSON hooks |
| **View state** | `lib/<feature>/bloc/` | What the widget tree consumes | Immutable | Domain model + presentation flags (`status`, `errorMessage`) |

The mapping happens at layer boundaries:

```
JSON  ──fromJson──►  DTO  ──repository.map──►  Domain  ──bloc.emit──►  State  ──widget──►  UI
```

`json_serializable` (`docs.flutter.dev/data-and-backend/serialization/json`) is the official Flutter team recommendation for the `fromJson` / `toJson` part. `freezed` (`pub.dev/packages/freezed`) is a third-party convenience that gives you immutable classes, `copyWith`, equality, and integrates with `json_serializable`. Both are widely used in authoritative samples — pick one project-wide and stay consistent.

---

## 8. Error handling

**The authoritative recommendation is typed exceptions plus failure states.** None of the three authoritative sources endorse functional `Either` types (`fpdart`, `dartz`) — they are community territory.

1. **Data layer throws a typed exception.** `WeatherRequestFailure`, `WeatherNotFoundFailure`, `NetworkFailure`. These extend `Exception` (or a sealed base) and live with the data provider.
2. **Repository catches and rethrows or translates** at its boundary. Infrastructure exceptions (`SocketException`, `HttpException`) are caught and either rethrown as domain exceptions or surfaced as a typed failure.
3. **Bloc catches in the event handler** and emits a failure state.

```dart
on<WeatherRequested>((event, emit) async {
  emit(state.copyWith(status: WeatherStatus.loading));
  try {
    final weather = await _repository.getWeather(event.city);
    emit(state.copyWith(status: WeatherStatus.success, weather: weather));
  } on WeatherNotFoundFailure {
    emit(state.copyWith(
      status: WeatherStatus.failure,
      errorMessage: 'City not found',
    ));
  } catch (_) {
    emit(state.copyWith(
      status: WeatherStatus.failure,
      errorMessage: 'Something went wrong',
    ));
  }
});
```

Use `addError` for unrecoverable errors that should be reported but not interrupt the UI; pair with a global `BlocObserver.onError` for logging (`bloclibrary.dev/bloc-concepts`).

---

## 9. Dependency injection

**All three authoritative sources land on the same answer: widget-tree DI rooted in `package:provider`, not service locators.**

- Flutter team: "Based on their experience building Flutter apps, teams at Google recommend using `package:provider` to implement dependency injection" (`docs.flutter.dev/app-architecture/case-study/dependency-injection`).
- Bloc library: `RepositoryProvider` and `MultiRepositoryProvider` are the recommended primitives. "Internally, `package:flutter_bloc` uses `package:provider` to implement `BlocProvider`, `MultiBlocProvider`, `RepositoryProvider`, and `MultiRepositoryProvider`" (`bloclibrary.dev/flutter-bloc-concepts`).
- VGV: the `very_good_core` template uses `RepositoryProvider` at the top of the tree — no `get_it` dependency in the canonical starter.

The widely-circulated "VGV uses get_it + injectable" claim is misattribution. `get_it`, `injectable`, and `kiwi` are listed by the Flutter team as alternatives, not endorsements.

### Canonical wiring

```dart
void main() {
  bootstrap(() => const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository(...)),
        RepositoryProvider(create: (_) => WeatherRepository(...)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => AppBloc(
            authRepository: ctx.read<AuthRepository>(),
          )),
        ],
        child: MaterialApp.router(/* ... */),
      ),
    );
  }
}
```

- **Repositories live above blocs.** A bloc can `ctx.read<XRepository>()`; a repository never reads a bloc.
- **Feature-scoped blocs live inside the route builder**, not at the root. Don't promote a feature bloc to global unless multiple routes share it.
- **Use `context.read<T>()` for one-shot access** (in callbacks); use `context.watch<T>()` or `BlocBuilder` for rebuild subscriptions.

---

## 10. Testing

The testing toolchain is the most consistent point across all authoritative sources.

### Toolchain

| Tool | Use | Source |
|---|---|---|
| `flutter_test` | Widget tests | Flutter team |
| `bloc_test` | Bloc/Cubit tests | `bloclibrary.dev/testing` |
| `mocktail` | Mocking — over `mockito` | `bloclibrary.dev/testing`, VGV |
| `alchemist` | Golden file tests | VGV (Betterment co-author) |
| `mockingjay` | Mocking `go_router` navigation | VGV |
| `integration_test` | End-to-end on device/emulator | Flutter team |
| `very_good_coverage` | Coverage threshold in CI | VGV |

`mocktail` is preferred over `mockito` because it doesn't require code generation and works cleanly with null-safety (`bloclibrary.dev/testing`).

### Coverage

VGV's stated bar: 100% coverage on all projects (`engineering.verygood.ventures/testing/testing_overview`). In practice teams set a CI gate (e.g., 95–100%) using `very_good_coverage`.

### Test organization

- `test/` mirrors `lib/`.
- Bloc tests are grouped by **event name** (`group('WeatherRequested', () { ... })`).
- Widget tests are grouped by **behavior** (`'renders'`, `'navigation'`).
- Repository tests are grouped by **method**.
- Create **private mocks per test file** — don't share a global `MockX` across files.

### Bloc test shape

```dart
void main() {
  group('WeatherCubit', () {
    late WeatherRepository repository;
    late WeatherCubit cubit;

    setUp(() {
      repository = _MockWeatherRepository();
      cubit = WeatherCubit(repository: repository);
    });

    group('fetchWeather', () {
      blocTest<WeatherCubit, WeatherState>(
        'emits [loading, success] when repository succeeds',
        setUp: () {
          when(() => repository.getWeather(any()))
              .thenAnswer((_) async => _fakeWeather);
        },
        build: () => cubit,
        act: (c) => c.fetchWeather('Paris'),
        expect: () => <WeatherState>[
          const WeatherState(status: WeatherStatus.loading),
          WeatherState(status: WeatherStatus.success, weather: _fakeWeather),
        ],
        verify: (_) {
          verify(() => repository.getWeather('Paris')).called(1);
        },
      );

      blocTest<WeatherCubit, WeatherState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(() => repository.getWeather(any()))
              .thenThrow(WeatherRequestFailure());
        },
        build: () => cubit,
        act: (c) => c.fetchWeather('Paris'),
        expect: () => const <WeatherState>[
          WeatherState(status: WeatherStatus.loading),
          WeatherState(status: WeatherStatus.failure),
        ],
      );
    });
  });
}

class _MockWeatherRepository extends Mock implements WeatherRepository {}
```

### Widget tests

Test **behavior, not properties**. "Verify that tapping a button triggers the correct action" — not "verify that the button has color X." For widgets that consume a bloc, use `MockBloc` from `bloc_test` and pump the widget inside a `BlocProvider.value`.

### Golden tests

Use `alchemist` for purely visual widgets (charts, custom painters, design-system primitives). Don't golden a widget whose appearance depends on environment-specific text rendering — pin the font.

---

## 11. Code generation

The standard stack is `build_runner` + `json_serializable` + optionally `freezed`.

- One generated `part 'x.g.dart'` per JSON-serialized type.
- One generated `part 'x.freezed.dart'` per freezed class.
- Run `dart run build_runner watch --delete-conflicting-outputs` during development.
- Decide once per repo: **commit generated files** (faster CI, larger diffs) or **regenerate in CI** (cleaner diffs, slightly slower builds). Don't mix.

Disable `invalid_annotation_target` when combining freezed + json_serializable — call it out in `analysis_options.yaml`.

---

## 12. Navigation with go_router

`go_router` is "the recommended choice for most production Flutter apps" (`docs.flutter.dev/ui/navigation`, `pub.dev/packages/go_router`). It is maintained by the Flutter team.

### VGV's specific rules (`engineering.verygood.ventures/development/ui/navigation`)

- Prefer **typed routes** over string paths to eliminate typos and parameter-casting bugs.
- Use **`go`** (replace) over **`push`** (stack-grow) unless you genuinely need a back-stack.
- Use **`ShellRoute`** for persistent navigation chrome (bottom nav, side rail) — each shell owns a distinct `Navigator`.
- **Cap nesting at two levels.** Three nested shells become undebuggable; if you think you need a third, the UX is the problem.

### Bloc integration

- Place blocs scoped to one route inside that route's `builder`.
- Place blocs that span multiple routes higher — typically just under `MaterialApp.router` via `MultiBlocProvider`, so a `ShellRoute` and its children share them.
- Navigate from a bloc-driven side effect via `BlocListener`:

```dart
BlocListener<AuthBloc, AuthState>(
  listenWhen: (prev, curr) => prev.status != curr.status,
  listener: (context, state) {
    switch (state.status) {
      case AuthStatus.authenticated:
        context.go('/home');
      case AuthStatus.unauthenticated:
        context.go('/login');
      case _:
        break;
    }
  },
  child: ...,
);
```

The bloc itself never imports `go_router` or `BuildContext`.

---

## 13. Theming with Material 3

Material 3 is the default for `ThemeData` since the M3 migration (`docs.flutter.dev/release/breaking-changes/material-3-default`). The canonical setup:

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(/* … */),
  extensions: const [AppSpacing(), AppRadii()],
);
```

### `ColorScheme.fromSeed`

Generate the full M3 tonal palette from a single seed color. Build both `Brightness.light` and `Brightness.dark` variants from the same seed (`api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html`).

### `ThemeExtension<T>` for design tokens

Anything that isn't a `ColorScheme` color or a `TextTheme` style — bespoke gradients, semantic colors, spacing scales, radius scales — goes in a `ThemeExtension` (`api.flutter.dev/flutter/material/ThemeExtension-class.html`):

```dart
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({this.xs = 4, this.sm = 8, this.md = 16, this.lg = 24});
  final double xs, sm, md, lg;

  @override
  AppSpacing copyWith({double? xs, double? sm, double? md, double? lg}) =>
      AppSpacing(xs: xs ?? this.xs, sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg);

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
    );
  }
}
```

Access via `Theme.of(context).extension<AppSpacing>()!`.

---

## 14. Modularization with melos

For repos with more than one package — and any VGV-style app has at least three (`<x>_api`, `<x>_repository`, the app) — use **melos** (`pub.dev/packages/melos`, `melos.invertase.dev`).

- `melos.yaml` at the repo root lists packages and scripts.
- `melos bootstrap` links every local package by path.
- `melos run analyze` / `melos run test` fan out across all packages.
- **Categories** group packages for targeted commands (e.g., `melos run test --no-select --category data`).

**When to extract into a package:**

1. **Always** for raw data sources — they belong in `packages/<x>_api/`.
2. **Always** for repositories — `packages/<x>_repository/`.
3. **Optionally** for shared design-system primitives — `packages/ui_kit/`.
4. **For features**, only when the feature is reused across multiple apps in the monorepo or has zero coupling to the host app. Otherwise the feature stays in `lib/<feature>/`.

---

## 15. Linting baseline

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore     # required when combining freezed + json_serializable
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.config.dart"
```

- **`very_good_analysis`** is the de-facto strict baseline for the Flutter community (`pub.dev/packages/very_good_analysis`).
- **`bloc_lint`** (`bloclibrary.dev/lint`) layers bloc-specific architectural rules. Two of its rules are non-negotiable for this architecture:
  - `avoid_flutter_imports` — bloc / cubit files must not import `package:flutter/*`. This is the mechanical enforcement of "the business-logic layer is pure Dart."
  - `prefer_cubit` — nudges the default toward Cubit; opt into Bloc when justified.
- **`custom_lint`** (`pub.dev/packages/custom_lint`) lets you write project-specific architectural rules — the bundle in this repo includes one for "domain layer must not import Flutter" and "presentation layer must not import data layer directly."

---

## 16. Areas where authoritative sources disagree

| # | Topic | Position A | Position B | This doc's resolution |
|---|---|---|---|---|
| 1 | Middle-tier abstraction | Flutter team: **ViewModel** (MVVM) | Bloc lib / VGV: **Bloc/Cubit** | Use Bloc/Cubit; the role is identical, the name is just terminology. |
| 2 | Layer count | Flutter team: 2–3 layers | VGV: 4 named layers | Same layers, different chunking. Use VGV's 4 names for clarity. |
| 3 | Code-gen for models | Flutter team docs: plain Dart + `json_serializable` | VGV/Bloc tutorials: `freezed` | Either is fine. Pick one project-wide. `freezed` if you want sum types and `copyWith` for free. |
| 4 | Functional error types (`fpdart`, `dartz`) | Not endorsed by any authoritative source | Popular in community | **Don't use** as a default. Use typed exceptions + failure states. |
| 5 | DI mechanism | Flutter team / Bloc lib / VGV all recommend **widget-tree DI via `provider`** | Community blogs often cite `get_it` / `injectable` | **Widget-tree DI.** Service locators are not the recommended path. |

---

## Quick reference: the rules

Every rule below is enforceable. See `RULES.md` for the agent-checkable, numbered cheatsheet derived from this document.

1. Business logic is pure Dart — no `package:flutter/*` imports in any `*_bloc.dart` / `*_cubit.dart` / `*_state.dart` / `*_event.dart`.
2. Blocs do not know about other blocs.
3. The data layer is the single source of truth.
4. Dependencies flow downward: presentation → business logic → repository → data. Never reverse.
5. One repository per domain.
6. Repositories never expose DTOs upward.
7. Default to Cubit; reach for Bloc when you need events.
8. Events are past-tense nouns; states are nouns; equality is mandatory.
9. Pick one state shape (status enum or sealed union) per feature; document why.
10. Wire dependencies via `RepositoryProvider` / `BlocProvider`, not a service locator.
11. Tests mirror `lib/`; bloc tests group by event name; widget tests test behavior.
12. Use `mocktail`, not `mockito`. Use `alchemist` for goldens. Use `mockingjay` for `go_router` mocking.
13. Aim for 95–100% line coverage; gate the CI build on it.
14. Use `go_router`; prefer typed routes; cap shell nesting at two.
15. Theme via `ColorScheme.fromSeed` + `ThemeExtension`; never hard-code colors in widgets.
16. Use `melos` for monorepos; extract data and repository layers into `packages/`.
17. `analysis_options.yaml` includes `very_good_analysis`; `bloc_lint` runs in CI.

---

## References

### Flutter team
- [Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts)
- [Architecture case study — UI layer](https://docs.flutter.dev/app-architecture/case-study/ui-layer)
- [Architecture case study — Data layer](https://docs.flutter.dev/app-architecture/case-study/data-layer)
- [Architecture case study — Dependency injection](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Architecture case study — Testing](https://docs.flutter.dev/app-architecture/case-study/testing)
- [Navigation and routing](https://docs.flutter.dev/ui/navigation)
- [JSON and serialization](https://docs.flutter.dev/data-and-backend/serialization/json)
- [ColorScheme.fromSeed](https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html)
- [ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)
- [Material 3 default migration](https://docs.flutter.dev/release/breaking-changes/material-3-default)
- [flutter/samples — compass_app](https://github.com/flutter/samples/tree/main/compass_app)

### Bloc library (Felix Angelov)
- [Architecture](https://bloclibrary.dev/architecture/)
- [Modeling state](https://bloclibrary.dev/modeling-state/)
- [Naming conventions](https://bloclibrary.dev/naming-conventions/)
- [Flutter Bloc concepts](https://bloclibrary.dev/flutter-bloc-concepts/)
- [Testing](https://bloclibrary.dev/testing/)
- [Lint](https://bloclibrary.dev/lint/)
- [avoid_flutter_imports](https://bloclibrary.dev/lint-rules/avoid_flutter_imports/)
- [prefer_cubit](https://bloclibrary.dev/lint-rules/prefer_cubit/)
- [Flutter Weather tutorial](https://bloclibrary.dev/tutorials/flutter-weather/)
- [Flutter Login tutorial](https://bloclibrary.dev/tutorials/flutter-login/)

### Very Good Ventures
- [Engineering — Architecture](https://engineering.verygood.ventures/architecture/)
- [Engineering — Philosophy](https://engineering.verygood.ventures/general-practices/philosophy/)
- [Engineering — State handling](https://engineering.verygood.ventures/state_management/state_handling/)
- [Engineering — Bloc event transformers](https://engineering.verygood.ventures/development/state_management/bloc_event_transformers/)
- [Engineering — Testing overview](https://engineering.verygood.ventures/testing/testing_overview/)
- [Engineering — Golden file testing](https://engineering.verygood.ventures/development/testing/testing_golden_file/)
- [Engineering — Routing](https://engineering.verygood.ventures/development/ui/navigation/)
- [Engineering — Barrel files](https://engineering.verygood.ventures/development/architecture/barrel_files/)
- [VGV blog — Very Good Layered Architecture](https://verygood.ventures/blog/very-good-flutter-architecture/)
- [VGV blog — Why we use flutter_bloc](https://www.verygood.ventures/blog/why-we-use-flutter-bloc)
- [very_good_analysis](https://pub.dev/packages/very_good_analysis)
- [very_good_core](https://github.com/VeryGoodOpenSource/very_good_core)

### Packages
- [go_router](https://pub.dev/packages/go_router)
- [freezed](https://pub.dev/packages/freezed)
- [build_runner](https://pub.dev/packages/build_runner)
- [melos](https://melos.invertase.dev/)
- [custom_lint](https://pub.dev/packages/custom_lint)
- [mocktail](https://pub.dev/packages/mocktail)
- [alchemist](https://pub.dev/packages/alchemist)
- [mockingjay](https://pub.dev/packages/mockingjay)
