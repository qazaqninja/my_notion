import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/db/quill_database.dart' hide Page;
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
import 'features/vault/presentation/pages/tags_page.dart';
import 'features/editor/presentation/pages/editor_beta_page.dart';
import 'features/editor/presentation/pages/editor_page.dart';
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
    _router = _buildRouter(_vaultBloc);
    // Restore last-opened vault.
    _vaultBloc.tryRestore();
  }

  @override
  void dispose() {
    _remindersBloc.close();
    _vaultBloc.close();
    _themeCubit.close();
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _themeCubit),
          BlocProvider.value(value: _vaultBloc),
          BlocProvider.value(value: _remindersBloc),
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
    initialLocation: '/',
    refreshListenable: _StreamListenable(vault.stream),
    redirect: (context, state) {
      final s = vault.state;
      final path = state.matchedLocation;
      final isLab = path == '/lab';
      final isPicker = path == '/' || path == '/vault';
      if (s is VaultLoaded) {
        if (isPicker) return '/home';
      } else {
        if (!isLab && !isPicker) return '/vault';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const VaultPickerPage()),
      GoRoute(path: '/vault', builder: (_, __) => const VaultPickerPage()),
      GoRoute(path: '/lab', builder: (_, __) => const ComponentSheetPage()),
      ShellRoute(
        builder: (context, state, child) {
          final ulid = state.pathParameters['ulid'];
          return VaultShellPage(activeUlid: ulid, child: child);
        },
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomePage()),
          GoRoute(
            path: '/editor/:ulid',
            builder: (context, state) => EditorPage(
              key: ValueKey(
                  '${state.pathParameters['ulid']}#${state.uri.queryParameters['anchor'] ?? ''}'),
              ulid: state.pathParameters['ulid']!,
              anchor: state.uri.queryParameters['anchor'],
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
          GoRoute(path: '/databases', builder: (_, __) => const DatabasesPage()),
          GoRoute(path: '/tags', builder: (_, __) => const TagsPage()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
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
