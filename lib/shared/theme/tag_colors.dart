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

/// Semantic accent colours for GFM admonition callouts and any other
/// "kind-of-note" surface. Five distinct hues so info / tip / warning /
/// important / caution read as different at a glance. Match the design's
/// callout palette exactly. Use [calloutColor] to map a kind keyword.
const Color kCalloutInfo = Color(0xFF4A90D9);
const Color kCalloutTip = Color(0xFF55A06A);
const Color kCalloutImportant = Color(0xFF8E5CD0);
const Color kCalloutWarning = Color(0xFFD08F3D);
const Color kCalloutDanger = Color(0xFFCB5A4F);

/// Toast warning accent. No equivalent in `QuillTokens` because the
/// warning dot only appears in toast cards — defined here for a single
/// source of truth across light and dark themes.
const Color kToastWarn = Color(0xFFB58A3A);

/// Stage / status colours for sales-pipeline-shaped databases. The five
/// hues match `tokens.jsx:stage` exactly. Used by the timeline-view bar
/// renderer and any other "deal stage"-like grouping.
const Color kStageWon = kCalloutTip;     // green = won / expand
const Color kStageChurn = Color(0xFFA8584C); // slightly muted red
const Color kStagePilot = kCalloutInfo;  // blue
const Color kStageEval = Color(0xFFB39342); // ochre
const Color kStageNegot = Color(0xFFB46F4F); // terracotta

/// Resolve a sales-stage substring to its bar/dot colour. Walks in
/// priority order — first match wins. Returns null when nothing matches
/// so the caller can fall back to a theme accent.
Color? stageColor(String stage) {
  final s = stage.toLowerCase();
  if (s.contains('won') || s.contains('expand')) return kStageWon;
  if (s.contains('churn')) return kStageChurn;
  if (s.contains('pilot')) return kStagePilot;
  if (s.contains('eval')) return kStageEval;
  if (s.contains('negot')) return kStageNegot;
  return null;
}

/// Resolve a callout kind keyword (note/tip/important/warning/warn/
/// caution/danger) to its accent colour. Returns null for unknown kinds
/// so the caller can fall back to its theme accent.
Color? calloutColor(String kind) {
  switch (kind) {
    case 'note':
      return kCalloutInfo;
    case 'tip':
      return kCalloutTip;
    case 'important':
      return kCalloutImportant;
    case 'warning':
    case 'warn':
      return kCalloutWarning;
    case 'caution':
    case 'danger':
      return kCalloutDanger;
    default:
      return null;
  }
}

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
