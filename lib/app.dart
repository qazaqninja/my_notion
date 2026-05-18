import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/db/quill_database.dart' hide Page;
import 'core/network/backend_endpoint.dart';
import 'core/routing/routes.dart';
// Composition root — app.dart is the one place that constructs concrete
// data-layer impls and wires them through RepositoryProvider. Other
// presentation files MUST consume the abstract interfaces, never the
// _impl classes. Per docs/RULES.md CA-04 the composition-root exception.
import 'features/database/data/repositories/database_repository_impl.dart';
import 'features/database/domain/repositories/database_repository.dart';
import 'features/relations/data/relations_repository_impl.dart';
import 'features/relations/domain/repositories/relations_repository.dart';
import 'features/database/presentation/pages/database_table_page.dart';
import 'features/database/presentation/pages/databases_page.dart';
import 'features/reminders/data/datasources/notification_scheduler.dart';
import 'features/reminders/presentation/bloc/reminders_bloc.dart';
import 'features/forms/data/repositories/drift_form_bearing_pages_repository.dart';
import 'features/forms/data/repositories/http_forms_repository.dart';
import 'features/forms/domain/repositories/form_bearing_pages_repository.dart';
import 'features/forms/domain/repositories/forms_repository.dart';
import 'features/sharing/data/receive_sharing_intent_source.dart';
import 'features/sharing/presentation/incoming_share_binder.dart';
import 'features/sync/data/repositories/http_sync_repository.dart';
import 'features/sync/domain/repositories/sync_repository.dart';
import 'features/sync/presentation/bloc/sync_bloc.dart';
import 'features/sync/presentation/bloc/sync_event.dart';
import 'features/vault/presentation/pages/tags_page.dart';
import 'features/editor/presentation/pages/editor_beta_page.dart';
import 'features/editor/presentation/pages/editor_page.dart';
import 'features/settings/data/editor_preferences_store.dart';
import 'features/settings/presentation/cubit/editor_preferences_cubit.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/vault/data/indexer.dart';
import 'features/vault/data/repositories/vault_repository_impl.dart';
import 'features/vault/domain/repositories/vault_repository.dart';
import 'features/vault/presentation/bloc/vault_bloc.dart';
import 'features/vault/presentation/bloc/vault_state.dart';
import 'features/vault/presentation/pages/home_page.dart';
import 'features/vault/presentation/pages/vault_picker_page.dart';
import 'features/vault/presentation/pages/vault_shell_page.dart';
import 'shared/theme/app_theme_mode.dart';
import 'shared/theme/theme_cubit.dart';
import 'shared/theme/tokens.dart';
import 'shared/widgets/component_sheet_page.dart';
import 'shared/widgets/quill_toast.dart';

class QuillApp extends StatefulWidget {
  const QuillApp({super.key});

  @override
  State<QuillApp> createState() => _QuillAppState();
}

class _QuillAppState extends State<QuillApp> {
  late final QuillDatabase _db;
  late final VaultRepositoryImpl _repo;
  late final DatabaseRepository _dbRepo;
  late final RelationsRepository _relationsRepo;
  late final Indexer _indexer;
  late final VaultBloc _vaultBloc;
  late final ThemeCubit _themeCubit;
  late final NotificationScheduler _scheduler;
  late final RemindersBloc _remindersBloc;
  late final SyncRepository _syncRepo;
  late final SyncBloc _syncBloc;
  // D28 cutover slice 1b (M1665): the WYSIWYG opt-in. Constructed
  // sync at app start, then `..hydrate()` loads the persisted
  // SharedPreferences value asynchronously. /editor/:ulid (slice 1c)
  // will fork on `state.useBetaEditor`; default false until the user
  // flips the Settings → Advanced toggle.
  late final EditorPreferencesCubit _editorPreferencesCubit;
  // E51: forms repo lives alongside the sync one — same backend, same
  // base URL — but stays bloc-less for now. The editor consumes it via
  // RepositoryProvider directly inside a FutureBuilder dialog.
  late final FormsRepository _formsRepo;
  // E58b: local Drift-backed loader for the Settings → Forms pane.
  // No network — reads frontmatter_json directly off the cache and
  // projects to FormBearingPage rows. Constructed after _db, before
  // _syncBloc, so the RepositoryProvider chain can hand it to the
  // pane's FormBearingPagesCubit.
  late final FormBearingPagesRepository _formBearingPagesRepo;
  // F2: binds the OS share-sheet stream to QuickCapture for whichever
  // vault is currently loaded. Created in initState, attached after
  // the bloc + restore are kicked off, detached on dispose.
  late final IncomingShareBinder _shareBinder;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _db = QuillDatabase();
    _repo = VaultRepositoryImpl.local();
    _indexer = Indexer(_db, _repo.datasource);
    _dbRepo = DatabaseRepositoryImpl(_db, vault: _repo, indexer: _indexer);
    _relationsRepo = RelationsRepositoryImpl(_db);
    _vaultBloc = VaultBloc(repo: _repo, indexer: _indexer, db: _db);
    _themeCubit = ThemeCubit()..load();
    // Reminders: B4 of the 1m-loop plan. The platform-channel init is
    // fire-and-forget — schedule()/cancel() each guard their own
    // _initialised flag, so the bloc doesn't block on init completion.
    _scheduler = LocalNotificationScheduler();
    unawaited(_scheduler.init());
    _remindersBloc = RemindersBloc(scheduler: _scheduler);
    // V2 backend client (Phase E E12-E13). baseUrl currently hard-
    // coded to localhost via kBackendHttpBaseUrl — a settings page
    // (slice E14+) will let users override it. E57 promoted the
    // constant out of this file so editor_page.dart's WS factory
    // + the kebab's "Copy form link" handler share one source of
    // truth.
    _syncRepo = HttpSyncRepository(baseUrl: kBackendHttpBaseUrl);
    _formsRepo = HttpFormsRepository(baseUrl: kBackendHttpBaseUrl);
    // E58b: backed by the same QuillDatabase as the rest of the
    // data layer; nothing async on construction so it's safe to
    // build inline.
    _formBearingPagesRepo = DriftFormBearingPagesRepository(_db);
    _syncBloc = SyncBloc(repo: _syncRepo)
      // E15: restore the persisted JWT (if any) so a quit + relaunch
      // doesn't force users to re-authenticate.
      ..add(const SyncRestoreRequested());
    // D28 cutover slice 1b (M1665) + BL-01 slice 2 (M1677): hydrate
    // from SharedPreferences in the background via the lazy store
    // wrapper. The cubit starts at `useBetaEditor: true` (D29
    // default) and emits the persisted value once
    // `SharedPreferences.getInstance()` resolves + the user's
    // recorded preference flows through `hydrate()`.
    _editorPreferencesCubit = EditorPreferencesCubit(
      LazySharedPreferencesEditorPreferencesStore(
        SharedPreferences.getInstance(),
      ),
    );
    unawaited(_editorPreferencesCubit.hydrate());
    _router = _buildRouter(_vaultBloc);
    // F2: start the inbound share-sheet binder. It attaches to the
    // VaultBloc stream and starts/stops an IncomingShareListener as
    // vaults load and unload. Fire-and-forget — attach() awaits one
    // initial-state read and starts the subscription.
    _shareBinder = IncomingShareBinder(
      vaultBloc: _vaultBloc,
      sourceFactory: ReceiveSharingIntentSource.new,
    );
    unawaited(_shareBinder.attach());
    // Restore last-opened vault.
    _vaultBloc.tryRestore();
  }

  @override
  void dispose() {
    // F2: detach the share binder first — it holds a Stream sub on
    // VaultBloc which closes immediately below.
    unawaited(_shareBinder.detach());
    _syncBloc.close();
    _remindersBloc.close();
    _vaultBloc.close();
    _themeCubit.close();
    _editorPreferencesCubit.close();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DI-02 (docs/RULES.md): repositories are the outermost wrappers so
    // any future bloc that resolves a repo from `context` inside
    // BlocProvider.create can find it.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuillDatabase>.value(value: _db),
        RepositoryProvider<VaultRepository>.value(value: _repo),
        RepositoryProvider<DatabaseRepository>.value(value: _dbRepo),
        RepositoryProvider<RelationsRepository>.value(value: _relationsRepo),
        RepositoryProvider<Indexer>.value(value: _indexer),
        RepositoryProvider<NotificationScheduler>.value(value: _scheduler),
        RepositoryProvider<SyncRepository>.value(value: _syncRepo),
        RepositoryProvider<FormsRepository>.value(value: _formsRepo),
        // E58b-iii: FormBearingPagesRepository feeds only the
        // Settings → Forms pane today, so a route-scoped Provider
        // would be more granular per DI-03. We hoist it to root
        // for symmetry with FormsRepository above (same pattern,
        // both repos are stateless thin wrappers) — when a second
        // consumer appears or the app grows multi-vault, revisit.
        RepositoryProvider<FormBearingPagesRepository>.value(
            value: _formBearingPagesRepo),
      ],
      child: MultiBlocProvider(
        // DI-03 (docs/RULES.md): blocs are normally scoped to the
        // route that consumes them. The four below are deliberate
        // exceptions, justified inline:
        //
        // - ThemeCubit: cross-cutting; every route reads it for
        //   makeTheme() in MaterialApp.router.
        // - VaultBloc: the app is single-vault, and the editor +
        //   sidebar + database views all read the same state.
        // - RemindersBloc: subscribed to from the editor's
        //   MultiBlocListener bridge so frontmatter `reminder:` edits
        //   translate to OS notifications.
        // - SyncBloc: editor save → push bridge AND settings → sync
        //   pane both read the same auth + push-queue state. Two
        //   instances would mean the editor pushes through one bloc
        //   while the settings pane authenticates against another.
        providers: [
          BlocProvider.value(value: _themeCubit),
          BlocProvider.value(value: _vaultBloc),
          BlocProvider.value(value: _remindersBloc),
          BlocProvider.value(value: _syncBloc),
          // D28 cutover slice 1c (M1667): root-scoped because two
          // sibling consumers read the same cubit and must agree on
          // the live value:
          //   1. `/editor/:ulid` GoRoute builder (`app.dart` below)
          //      via `BlocSelector` — picks `EditorPage` vs
          //      `EditorBetaPage` on each navigation.
          //   2. Settings → Advanced "Use beta WYSIWYG editor"
          //      toggle row (`settings_page.dart` `_advancedPane`).
          // Route-scoping would force the user to restart the app
          // (or re-route the editor) to see toggle changes.
          BlocProvider.value(value: _editorPreferencesCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp.router(
              title: 'Quill',
              debugShowCheckedModeBanner: false,
              theme: makeTheme(Brightness.light, themeState.accent),
              darkTheme: makeTheme(Brightness.dark, themeState.accent),
              themeMode: switch (themeState.mode) {
                AppThemeMode.light => ThemeMode.light,
                AppThemeMode.dark => ThemeMode.dark,
                AppThemeMode.system => ThemeMode.system,
              },
              routerConfig: _router,
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: themeState.compact
                        ? const TextScaler.linear(0.92)
                        : mq.textScaler,
                  ),
                  child: QuillToastHost(
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

GoRouter _buildRouter(VaultBloc vault) {
  return GoRouter(
    initialLocation: Routes.picker,
    refreshListenable: _StreamListenable(vault.stream),
    redirect: (context, state) {
      final s = vault.state;
      final path = state.matchedLocation;
      final isLab = path == Routes.lab;
      final isPicker = path == Routes.picker || path == Routes.vault;
      if (s is VaultLoaded) {
        if (isPicker) return Routes.home;
      } else {
        if (!isLab && !isPicker) return Routes.vault;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.picker, builder: (_, __) => const VaultPickerPage()),
      GoRoute(path: Routes.vault, builder: (_, __) => const VaultPickerPage()),
      GoRoute(path: Routes.lab, builder: (_, __) => const ComponentSheetPage()),
      ShellRoute(
        builder: (context, state, child) {
          final ulid = state.pathParameters['ulid'];
          return VaultShellPage(activeUlid: ulid, child: child);
        },
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomePage()),
          GoRoute(
            path: '/editor/:ulid',
            // D30b cutover slice (M1757): collapse the M1667 BlocSelector
            // + buildEditorPageForFork indirection. The D-fp parity arc
            // closed at M1755 (26 D-fp actions ported); EditorBetaPage
            // now has full kebab feature parity with the legacy editor,
            // so the runtime fork has no remaining purpose. /editor-
            // beta/:ulid below still exists for direct beta entry +
            // backwards-compat with any wikilinks that hard-coded the
            // beta path; the two routes are now structurally identical
            // (same widget, same key shape).
            //
            // EditorPreferencesCubit + the Settings → Advanced "Use
            // beta WYSIWYG editor" toggle + the [buildEditorPageForFork]
            // helper + its M1673 widget tests are dead code as of this
            // commit but stay in the tree until D30c (next slice) for
            // a cleaner reverting-window if the new direct build
            // surfaces a regression during dogfood.
            builder: (context, state) => EditorBetaPage(
              key: ValueKey(
                'editor-${state.pathParameters['ulid']}',
              ),
              ulid: state.pathParameters['ulid']!,
            ),
          ),
          // Phase D D1 slice 23 (M1284): beta WYSIWYG editor backed by
          // super_editor + SuperEditorSerializer. Lives at /editor-beta/
          // until interaction parity (slices 24-27) + cutover (28-30)
          // promote it to the default /editor route.
          GoRoute(
            path: '/editor-beta/:ulid',
            builder: (context, state) => EditorBetaPage(
              key: ValueKey('beta-${state.pathParameters['ulid']}'),
              ulid: state.pathParameters['ulid']!,
            ),
          ),
          GoRoute(
            path: '/db/:dbId',
            builder: (context, state) => DatabaseTablePage(
              key: ValueKey('db-${state.pathParameters['dbId']}'),
              dbId: state.pathParameters['dbId']!,
            ),
            routes: [
              GoRoute(
                path: ':viewId',
                builder: (context, state) => DatabaseTablePage(
                  key: ValueKey(
                    'db-${state.pathParameters['dbId']}-${state.pathParameters['viewId']}',
                  ),
                  dbId: state.pathParameters['dbId']!,
                  viewId: state.pathParameters['viewId'],
                ),
              ),
            ],
          ),
          GoRoute(path: Routes.databases, builder: (_, __) => const DatabasesPage()),
          GoRoute(path: Routes.tags, builder: (_, __) => const TagsPage()),
          GoRoute(path: Routes.settings, builder: (_, __) => const SettingsPage()),
          GoRoute(
            path: '/settings/:section',
            builder: (context, state) => SettingsPage(
              section: state.pathParameters['section']!,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Bridges a stream to `Listenable` so go_router rebuilds on bloc state changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<void> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<void> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// D28 cutover branch helper (D30a / M1673): given the live
/// `useBetaEditor` value plus the route's `ulid` + optional `anchor`
/// query param, returns the editor widget the `/editor/:ulid`
/// GoRoute should render.
///
/// Split out as a top-level function so it can be unit-tested without
/// pumping a full app harness — the helper is pure given inputs.
/// Production calls it from the `BlocSelector` builder inside
/// `_buildRouter`. D30 will collapse this helper to a direct
/// `EditorBetaPage` build once the dogfood window closes.
Widget buildEditorPageForFork({
  required bool useBetaEditor,
  required String ulid,
  required String? anchor,
}) {
  if (useBetaEditor) {
    return EditorBetaPage(
      key: ValueKey('beta-fork-$ulid'),
      ulid: ulid,
    );
  }
  return EditorPage(
    key: ValueKey('$ulid#${anchor ?? ''}'),
    ulid: ulid,
    anchor: anchor,
  );
}
