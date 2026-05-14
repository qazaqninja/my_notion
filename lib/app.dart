import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/db/quill_database.dart' hide Page;
import 'features/editor/presentation/pages/editor_placeholder_page.dart';
import 'features/vault/data/indexer.dart';
import 'features/vault/data/repositories/vault_repository_impl.dart';
import 'features/vault/domain/repositories/vault_repository.dart';
import 'features/vault/presentation/bloc/vault_bloc.dart';
import 'features/vault/presentation/bloc/vault_state.dart';
import 'features/vault/presentation/pages/home_page.dart';
import 'features/vault/presentation/pages/vault_picker_page.dart';
import 'features/vault/presentation/pages/vault_shell_page.dart';
import 'shared/theme/theme_cubit.dart';
import 'shared/theme/tokens.dart';
import 'shared/widgets/component_sheet_page.dart';

class QuillApp extends StatefulWidget {
  const QuillApp({super.key});

  @override
  State<QuillApp> createState() => _QuillAppState();
}

class _QuillAppState extends State<QuillApp> {
  late final QuillDatabase _db;
  late final VaultRepositoryImpl _repo;
  late final Indexer _indexer;
  late final VaultBloc _vaultBloc;
  late final ThemeCubit _themeCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _db = QuillDatabase();
    _repo = VaultRepositoryImpl.local();
    _indexer = Indexer(_db, _repo.datasource);
    _vaultBloc = VaultBloc(repo: _repo, indexer: _indexer, db: _db);
    _themeCubit = ThemeCubit()..load();
    _router = _buildRouter(_vaultBloc);
    // Restore last-opened vault.
    _vaultBloc.tryRestore();
  }

  @override
  void dispose() {
    _vaultBloc.close();
    _themeCubit.close();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        BlocProvider.value(value: _vaultBloc),
      ],
      child: RepositoryProvider<QuillDatabase>.value(
        value: _db,
        child: RepositoryProvider<VaultRepository>.value(
          value: _repo,
          child: BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp.router(
                title: 'Quill',
                debugShowCheckedModeBanner: false,
                theme: makeTheme(Brightness.light, themeState.accent),
                darkTheme: makeTheme(Brightness.dark, themeState.accent),
                themeMode: themeState.mode,
                routerConfig: _router,
              );
            },
          ),
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
            builder: (context, state) => EditorPlaceholderPage(
              ulid: state.pathParameters['ulid']!,
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
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
