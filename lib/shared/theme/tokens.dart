import 'package:flutter/material.dart';

import 'accent.dart';
import 'quill_tokens.dart';

/// Shared spacing + radii, ported from `tokens.jsx`'s `T` object.
class QuillSpacing {
  const QuillSpacing._();

  static const double radiusSm = 4;
  static const double radiusMd = 6;
  static const double radiusLg = 8;
  static const double radiusXl = 12;

  /// Center editor column max width.
  static const double editorMax = 720;
}

/// Build a [QuillTokens] for the given brightness/accent. Hex values match
/// `tokens.jsx:10-58` exactly.
QuillTokens buildTokens(Brightness brightness, AccentKey accentKey) {
  if (brightness == Brightness.dark) {
    return QuillTokens(
      brightness: Brightness.dark,
      accentKey: accentKey,
      bg: const Color(0xFF1A1A1A),
      surface: const Color(0xFF1F1F1F),
      surface2: const Color(0xFF252523),
      sidebar: const Color(0xFF171716),
      text: const Color(0xFFE8E6E2),
      text2: const Color(0xFFA9A6A1),
      text3: const Color(0xFF777570),
      divider: Colors.white.withValues(alpha: 0.06),
      divider2: Colors.white.withValues(alpha: 0.10),
      hover: Colors.white.withValues(alpha: 0.04),
      hoverStrong: Colors.white.withValues(alpha: 0.07),
      selected: Colors.white.withValues(alpha: 0.06),
      accent: accentKey.color,
      accentTint: accentKey.tint,
      chipBg: Colors.white.withValues(alpha: 0.06),
      chipText: const Color(0xFFD4D2CE),
      chipBorder: Colors.white.withValues(alpha: 0.10),
      inputBg: Colors.white.withValues(alpha: 0.04),
      inputBorder: Colors.white.withValues(alpha: 0.10),
      danger: const Color(0xFFCB5A4F),
      dangerTint: const Color(0xFFCB5A4F).withValues(alpha: 0.16),
      success: const Color(0xFF5A8F6E),
      codeBg: const Color(0xFF101010),
    );
  }
  return QuillTokens(
    brightness: Brightness.light,
    accentKey: accentKey,
    bg: const Color(0xFFF8F6F2),
    surface: const Color(0xFFFBFAF6),
    surface2: const Color(0xFFF1EEE8),
    sidebar: const Color(0xFFF3F1EC),
    text: const Color(0xFF1A1A1A),
    text2: const Color(0xFF62605B),
    text3: const Color(0xFF94918B),
    divider: Colors.black.withValues(alpha: 0.05),
    divider2: Colors.black.withValues(alpha: 0.08),
    hover: Colors.black.withValues(alpha: 0.03),
    hoverStrong: Colors.black.withValues(alpha: 0.05),
    selected: Colors.black.withValues(alpha: 0.045),
    accent: accentKey.color,
    accentTint: accentKey.tint,
    chipBg: Colors.black.withValues(alpha: 0.04),
    chipText: const Color(0xFF3A3A38),
    chipBorder: Colors.black.withValues(alpha: 0.06),
    inputBg: Colors.black.withValues(alpha: 0.025),
    inputBorder: Colors.black.withValues(alpha: 0.06),
    danger: const Color(0xFFCB5A4F),
    dangerTint: const Color(0xFFCB5A4F).withValues(alpha: 0.16),
    success: const Color(0xFF5A8F6E),
    codeBg: const Color(0xFFF0EDE6),
  );
}

/// Build the full [ThemeData] for the app. `colorScheme` is sized minimally
/// — most colour reads happen through the [QuillTokens] extension.
ThemeData makeTheme(Brightness brightness, AccentKey accentKey) {
  final tokens = buildTokens(brightness, accentKey);
  final isDark = brightness == Brightness.dark;
  final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

  final interTheme = base.textTheme
      .apply(fontFamily: 'Inter', bodyColor: tokens.text, displayColor: tokens.text);

  return base.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentKey.color,
      brightness: brightness,
      surface: tokens.surface,
    ),
    textTheme: interTheme,
    primaryTextTheme: interTheme,
    dividerColor: tokens.divider,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    extensions: [tokens],
  );
}

/// Convenience for monospace fonts — design uses JetBrains Mono for ULIDs,
/// file paths, frontmatter keys, code blocks, cell numbers, and Kbd chips.
TextStyle mono({double? fontSize, FontWeight? fontWeight, Color? color, double? letterSpacing}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
