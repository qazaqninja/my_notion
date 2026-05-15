import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Matches `SidebarSearch` from `shell.jsx:34-49`. Tap opens the command
/// palette (Cmd-K) — wired in M9.
class SidebarSearch extends StatefulWidget {
  const SidebarSearch({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  State<SidebarSearch> createState() => _SidebarSearchState();
}

class _SidebarSearchState extends State<SidebarSearch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter:
            widget.onTap == null ? null : (_) => setState(() => _hover = true),
        onExit:
            widget.onTap == null ? null : (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: 'Open command palette (⌘K)',
            waitDuration: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.inputBg,
                border: Border.all(
                    color: _hover ? tokens.accent : tokens.divider2,
                    width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Row(
                children: [
                  QuillIcon('search',
                      size: 13,
                      strokeWidth: 1.8,
                      color: _hover ? tokens.text2 : tokens.text3),
                  const SizedBox(width: 7),
                  Text('Search',
                      style: TextStyle(
                          color: _hover ? tokens.text2 : tokens.text3,
                          fontSize: 12.5)),
                  const Spacer(),
                  const Kbd('⌘K'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
