import 'package:flutter/material.dart';

import 'accent.dart';

/// All non-Material design colours from `tokens.jsx`. Carried through the
/// widget tree as a [ThemeExtension] so widgets can read e.g. `t.text2` and
/// `t.divider` directly without re-deriving them from a [ColorScheme].
@immutable
class QuillTokens extends ThemeExtension<QuillTokens> {
  const QuillTokens({
    required this.brightness,
    required this.accentKey,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.sidebar,
    required this.text,
    required this.text2,
    required this.text3,
    required this.divider,
    required this.divider2,
    required this.hover,
    required this.hoverStrong,
    required this.selected,
    required this.accent,
    required this.accentTint,
    required this.chipBg,
    required this.chipText,
    required this.chipBorder,
    required this.inputBg,
    required this.inputBorder,
    required this.danger,
    required this.dangerTint,
    required this.success,
  });

  final Brightness brightness;
  final AccentKey accentKey;

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color sidebar;
  final Color text;
  final Color text2;
  final Color text3;
  final Color divider;
  final Color divider2;
  final Color hover;
  final Color hoverStrong;
  final Color selected;
  final Color accent;
  final Color accentTint;
  final Color chipBg;
  final Color chipText;
  final Color chipBorder;
  final Color inputBg;
  final Color inputBorder;

  /// Destructive / warning red — used for the "trash" icon, the danger
  /// pill on the locked-page badge, and the snooze-reminder error chip.
  final Color danger;

  /// Translucent danger background (~16% alpha) for pill backgrounds.
  final Color dangerTint;

  /// Positive / success green — used for the unlock chevron and the
  /// "saved" badge on the editor footer.
  final Color success;

  bool get isDark => brightness == Brightness.dark;

  static QuillTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<QuillTokens>();
    assert(ext != null, 'QuillTokens not found in Theme. Did you wrap with QuillApp?');
    return ext!;
  }

  @override
  QuillTokens copyWith({
    Brightness? brightness,
    AccentKey? accentKey,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? sidebar,
    Color? text,
    Color? text2,
    Color? text3,
    Color? divider,
    Color? divider2,
    Color? hover,
    Color? hoverStrong,
    Color? selected,
    Color? accent,
    Color? accentTint,
    Color? chipBg,
    Color? chipText,
    Color? chipBorder,
    Color? inputBg,
    Color? inputBorder,
    Color? danger,
    Color? dangerTint,
    Color? success,
  }) {
    return QuillTokens(
      brightness: brightness ?? this.brightness,
      accentKey: accentKey ?? this.accentKey,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      sidebar: sidebar ?? this.sidebar,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      divider: divider ?? this.divider,
      divider2: divider2 ?? this.divider2,
      hover: hover ?? this.hover,
      hoverStrong: hoverStrong ?? this.hoverStrong,
      selected: selected ?? this.selected,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      chipBg: chipBg ?? this.chipBg,
      chipText: chipText ?? this.chipText,
      chipBorder: chipBorder ?? this.chipBorder,
      inputBg: inputBg ?? this.inputBg,
      inputBorder: inputBorder ?? this.inputBorder,
      danger: danger ?? this.danger,
      dangerTint: dangerTint ?? this.dangerTint,
      success: success ?? this.success,
    );
  }

  @override
  QuillTokens lerp(ThemeExtension<QuillTokens>? other, double t) {
    if (other is! QuillTokens) return this;
    return QuillTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      accentKey: t < 0.5 ? accentKey : other.accentKey,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      divider2: Color.lerp(divider2, other.divider2, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      hoverStrong: Color.lerp(hoverStrong, other.hoverStrong, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipText: Color.lerp(chipText, other.chipText, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
