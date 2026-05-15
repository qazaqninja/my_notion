import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';

/// Renders a single person reference — a coloured initial circle plus
/// the name. Used by the `person` / `created_by` / `last_edited_by`
/// column types and anywhere a `who:` style value needs a face-shaped
/// preview. The colour is derived from the name so the same person
/// reads the same way across the vault.
class PersonChip extends StatelessWidget {
  const PersonChip({super.key, required this.name, this.compact = false});

  /// The display name. The first non-whitespace character supplies the
  /// initial; if the string is empty the chip falls back to `?`.
  final String name;

  /// When true, drops the name label and renders just the avatar
  /// (e.g. for dense table cells).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    final colour = categoricalColor(trimmed);
    // The avatar circle is always coloured (sage/blue/terracotta/…),
    // so the contrasting initial reads against the saturated fill —
    // the M3 onPrimary slot is the most semantically correct foreground.
    final onAvatar = Theme.of(context).colorScheme.onPrimary;
    final avatar = Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: onAvatar,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
    final tip = trimmed.isEmpty ? 'Unassigned' : trimmed;
    if (compact) {
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 400),
        child: avatar,
      );
    }
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              trimmed.isEmpty ? '—' : trimmed,
              style: TextStyle(fontSize: 12.5, color: tokens.text2),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

}
