import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../widgets/sidebar_widget.dart';

/// Desktop shell — sidebar on the left, child route content on the right.
/// Drives go_router's `ShellRoute`.
class VaultShellPage extends StatelessWidget {
  const VaultShellPage({super.key, required this.child, this.activeUlid});

  final Widget child;
  final String? activeUlid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Row(
        children: [
          SidebarWidget(activeUlid: activeUlid),
          Expanded(child: child),
        ],
      ),
    );
  }
}
