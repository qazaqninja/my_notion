import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Matches `SidebarSearch` from `shell.jsx:34-49`. Tap opens the command
/// palette (Cmd-K) — wired in M9.
class SidebarSearch extends StatelessWidget {
  const SidebarSearch({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.inputBg,
            border: Border.all(color: tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Row(
            children: [
              QuillIcon('search', size: 13, strokeWidth: 1.8, color: tokens.text3),
              const SizedBox(width: 7),
              Text('Search', style: TextStyle(color: tokens.text3, fontSize: 12.5)),
              const Spacer(),
              const Kbd('⌘K'),
            ],
          ),
        ),
      ),
    );
  }
}
