import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';

/// Bottom tab bar — matches `mobile.jsx`'s TabBar (Home / Editor / Bases /
/// Search).
class MobileTabBar extends StatelessWidget {
  const MobileTabBar({super.key});

  static Future<void> _openMostRecent(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final row = await (db.select(db.pages)
          ..orderBy([(p) =>
              OrderingTerm(expression: p.mtimeMs, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    if (!context.mounted) return;
    if (row == null) {
      context.go('/home');
    } else {
      context.go('/editor/${row.ulid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final route = GoRouterState.of(context).matchedLocation;
    // Mobile editor pane uses /home as its idle/landing surface.
    void goHome() => context.go('/home');
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider2, width: 0.5)),
      ),
      child: Row(
        children: [
          _Tab(
            icon: 'home',
            label: 'Home',
            active: route == '/home',
            onTap: goHome,
          ),
          _Tab(
            icon: 'file-md',
            label: 'Editor',
            active: route.startsWith('/editor'),
            onTap: route.startsWith('/editor')
                ? null
                : () => _openMostRecent(context),
          ),
          _Tab(
            icon: 'database',
            label: 'Bases',
            active: route.startsWith('/db'),
            onTap: () => context.go('/databases'),
          ),
          _Tab(
            icon: 'search',
            label: 'Search',
            active: false,
            onTap: () => context.read<CommandPaletteCubit>().open(),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.active, this.onTap});
  final String icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final color = active ? tokens.accent : tokens.text3;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuillIcon(icon, size: 20, strokeWidth: 1.6, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
