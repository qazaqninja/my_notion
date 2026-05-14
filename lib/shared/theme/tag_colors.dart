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
