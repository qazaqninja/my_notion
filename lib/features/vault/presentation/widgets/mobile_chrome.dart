import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Bottom tab bar — matches `mobile.jsx`'s TabBar (Home / Editor / Bases /
/// Search).
class MobileTabBar extends StatelessWidget {
  const MobileTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final route = GoRouterState.of(context).matchedLocation;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider2, width: 0.5)),
      ),
      child: Row(
        children: [
          _Tab(icon: 'home', label: 'Home', active: route == '/home', onTap: () => context.go('/home')),
          _Tab(icon: 'file-md', label: 'Editor', active: route.startsWith('/editor')),
          _Tab(icon: 'database', label: 'Bases', active: route.startsWith('/db')),
          _Tab(icon: 'search', label: 'Search', active: false),
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
