import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';

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
    final colour = _colorFor(trimmed);
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
        style: const TextStyle(
          color: Colors.white,
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

  /// Stable colour from name hash. Picks one of eight muted hues.
  static Color _colorFor(String name) {
    if (name.isEmpty) return const Color(0xFF8C8C8C);
    var h = 0;
    for (final code in name.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  static const _palette = <Color>[
    Color(0xFF5A8F6E), // sage
    Color(0xFF5A82B4), // blue
    Color(0xFFB46F4F), // terracotta
    Color(0xFF8B5FA8), // plum
    Color(0xFFB39342), // mustard
    Color(0xFF4F8FA4), // slate
    Color(0xFF9C5A6A), // mauve
    Color(0xFF6B8E7F), // moss
  ];
}
