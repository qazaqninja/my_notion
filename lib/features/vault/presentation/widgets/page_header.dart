import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Matches `PageHeader` from `shell.jsx:129-162`. Breadcrumb of mono path
/// segments, optional centre slot, action buttons on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.crumbs,
    this.actions,
    this.extra,
    this.onToggleSidebar,
  });

  final List<String> crumbs;
  final Widget? actions;
  final Widget? extra;
  final VoidCallback? onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onToggleSidebar,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Toggle sidebar',
            icon: QuillIcon('sidebar', size: 16, strokeWidth: 1.7, color: tokens.text3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < crumbs.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('/', style: TextStyle(color: tokens.text3.withValues(alpha: 0.5))),
                    ),
                  Flexible(
                    child: Tooltip(
                      message: crumbs[i],
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        crumbs[i],
                        style: mono(
                          fontSize: 12.5,
                          color: i == crumbs.length - 1 ? tokens.text2 : tokens.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (extra != null) ...[const SizedBox(width: 8), extra!],
          const SizedBox(width: 8),
          if (actions != null) actions! else _DefaultActions(tokens: tokens),
        ],
      ),
    );
  }
}

class _DefaultActions extends StatelessWidget {
  const _DefaultActions({required this.tokens});
  final QuillTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {},
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: QuillIcon('panel', size: 16, strokeWidth: 1.7, color: tokens.text3),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {},
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: QuillIcon('kebab-h', size: 16, strokeWidth: 1.7, color: tokens.text3),
        ),
      ],
    );
  }
}
