import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_state.dart';
import '../widgets/page_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final state = context.watch<VaultBloc>().state;
    return Column(
      children: [
        const PageHeader(crumbs: ['Home']),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Quill',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: tokens.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state is VaultLoaded
                      ? 'Your vault has ${state.pageCount} indexed pages.'
                      : 'Choose a vault to get started.',
                  style: TextStyle(fontSize: 14, color: tokens.text3, height: 1.55),
                ),
                const SizedBox(height: 32),
                Row(children: [
                  _Tile(
                    tokens: tokens,
                    icon: 'search',
                    title: 'Search & open',
                    subtitle: 'Cmd+K to find any page or database.',
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'database',
                    title: 'Databases',
                    subtitle: 'Browse every .database.yaml in the vault.',
                    onTap: () => context.go('/databases'),
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'gear',
                    title: 'Settings',
                    subtitle: 'Workspace, theme, export, advanced.',
                    onTap: () => context.go('/settings'),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _Tile(
                    tokens: tokens,
                    icon: 'plus',
                    title: 'New page',
                    subtitle: 'Cmd+N — title prompt, then a fresh .md.',
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'note',
                    title: 'Keyboard map',
                    subtitle: 'Press ? to list every shortcut.',
                  ),
                  const SizedBox(width: 16),
                  _Tile(
                    tokens: tokens,
                    icon: 'export',
                    title: 'Export',
                    subtitle: 'Markdown / HTML / PDF / CSV — Settings → Export.',
                    onTap: () => context.go('/settings'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final QuillTokens tokens;
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                QuillIcon(icon, size: 16, color: tokens.text2),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.text),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
