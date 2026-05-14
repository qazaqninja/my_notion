import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'shared/theme/accent.dart';
import 'shared/theme/quill_tokens.dart';
import 'shared/theme/theme_cubit.dart';
import 'shared/theme/tokens.dart';
import 'shared/widgets/component_sheet_page.dart';
import 'shared/widgets/quill_icon.dart';

class QuillApp extends StatelessWidget {
  const QuillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>(
      create: (_) => ThemeCubit()..load(),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp.router(
            title: 'Quill',
            debugShowCheckedModeBanner: false,
            theme: makeTheme(Brightness.light, state.accent),
            darkTheme: makeTheme(Brightness.dark, state.accent),
            themeMode: state.mode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/lab',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const _HomePlaceholder()),
    GoRoute(path: '/lab', builder: (_, __) => const ComponentSheetPage()),
  ],
);

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuillIcon('file-md', size: 48, color: tokens.text3),
            const SizedBox(height: 16),
            Text(
              'Quill',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tokens.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vault picker coming in M4. Visit /lab to see the component sheet.',
              style: TextStyle(fontSize: 14, color: tokens.text3),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                _AccentButton(accent: AccentKey.sage),
                _AccentButton(accent: AccentKey.terracotta),
                _ThemeButton(),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/lab'),
              child: Text('Open component sheet →', style: TextStyle(color: tokens.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  const _AccentButton({required this.accent});
  final AccentKey accent;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ThemeCubit>().state;
    final active = state.accent == accent;
    return GestureDetector(
      onTap: () => context.read<ThemeCubit>().setAccent(accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent.color : Colors.transparent,
          border: Border.all(color: accent.color, width: 1),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Text(
          accent.label,
          style: TextStyle(
            color: active ? Colors.white : accent.color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ThemeCubit>().state;
    final tokens = QuillTokens.of(context);
    return TextButton(
      onPressed: () => context.read<ThemeCubit>().cycleMode(),
      style: TextButton.styleFrom(
        side: BorderSide(color: tokens.divider2, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text('theme: ${state.mode.name}', style: TextStyle(color: tokens.text2)),
    );
  }
}
