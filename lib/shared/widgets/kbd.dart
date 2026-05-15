import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';

/// Keycap chip — used for ⌘K and friends. Matches `Kbd` from `primitives.jsx:248-260`.
class Kbd extends StatelessWidget {
  const Kbd(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Inverse-of-bg wash so the chiclet shows up against the
        // surface. `tokens.text` is dark on light, light on dark —
        // evaluates identically to the inverted black/white pattern.
        color: tokens.text.withValues(alpha: tokens.isDark ? 0.05 : 0.04),
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        border: Border.all(color: tokens.divider2, width: 0.5),
      ),
      child: Text(text, style: mono(fontSize: 11, color: tokens.text2)),
    );
  }
}
