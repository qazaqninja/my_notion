import 'package:flutter/material.dart';

/// Tag colour names — match `TAG_COLORS` keys in `tokens.jsx:62-83`.
enum TagColor { blue, green, yellow, orange, red, purple, gray, pink }

/// Per-tag colour pair for select/multi-select chips. Hue varies; chroma and
/// lightness kept low so they read as muted paper labels.
class TagPalette {
  const TagPalette({required this.bg, required this.text});
  final Color bg;
  final Color text;
}

const Map<TagColor, TagPalette> _light = {
  TagColor.blue: TagPalette(bg: Color(0xFFE4ECF1), text: Color(0xFF3B5366)),
  TagColor.green: TagPalette(bg: Color(0xFFE3ECE4), text: Color(0xFF3F5B47)),
  TagColor.yellow: TagPalette(bg: Color(0xFFEFE9D6), text: Color(0xFF665932)),
  TagColor.orange: TagPalette(bg: Color(0xFFEFE0D4), text: Color(0xFF6F4A30)),
  TagColor.red: TagPalette(bg: Color(0xFFEFDDD8), text: Color(0xFF723B33)),
  TagColor.purple: TagPalette(bg: Color(0xFFE4DFEC), text: Color(0xFF4F4467)),
  TagColor.gray: TagPalette(bg: Color(0xFFE5E2DD), text: Color(0xFF4B4945)),
  TagColor.pink: TagPalette(bg: Color(0xFFEFDFE5), text: Color(0xFF6D3F4F)),
};

const Map<TagColor, TagPalette> _dark = {
  TagColor.blue: TagPalette(bg: Color(0xFF28333C), text: Color(0xFFA9C2D2)),
  TagColor.green: TagPalette(bg: Color(0xFF2A3530), text: Color(0xFFA6C0B0)),
  TagColor.yellow: TagPalette(bg: Color(0xFF37321F), text: Color(0xFFD7C896)),
  TagColor.orange: TagPalette(bg: Color(0xFF3B2A1F), text: Color(0xFFD6AB88)),
  TagColor.red: TagPalette(bg: Color(0xFF3A2622), text: Color(0xFFD6A39B)),
  TagColor.purple: TagPalette(bg: Color(0xFF2D2839), text: Color(0xFFB7AED0)),
  TagColor.gray: TagPalette(bg: Color(0xFF2A2826), text: Color(0xFFB2AFA8)),
  TagColor.pink: TagPalette(bg: Color(0xFF3A272F), text: Color(0xFFD5A6B2)),
};

TagPalette tagPalette(Brightness brightness, TagColor color) {
  final map = brightness == Brightness.dark ? _dark : _light;
  return map[color] ?? map[TagColor.gray]!;
}

/// Shared categorical palette for chart bars, calendar event dots, timeline
/// bars, etc. Eight muted hues; matches the design's chart colours.
/// Use [kCategoricalNeutral] for `'—'` / empty / unbucketed values.
const List<Color> kCategoricalPalette = [
  Color(0xFF5A8F6E),
  Color(0xFF5A82B4),
  Color(0xFFB46F4F),
  Color(0xFF8B5FA8),
  Color(0xFFB39342),
  Color(0xFF4F8FA4),
  Color(0xFF9C5A6A),
  Color(0xFF6B8E7F),
];

const Color kCategoricalNeutral = Color(0xFF8C8C8C);

/// Stable hue assignment for a string label: maps a value to one of the
/// eight palette colours by hashing. Empty / `'—'` falls back to neutral.
/// Uses a Java-style 31-multiplier so re-orderings of label characters
/// produce different colours.
Color categoricalColor(String value) {
  if (value.isEmpty || value == '—') return kCategoricalNeutral;
  var h = 0;
  for (final code in value.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return kCategoricalPalette[h % kCategoricalPalette.length];
}
