/// H4d-ii — deterministically map a userId to one of 8 distinct
/// hex colors used by the remote-cursor overlay (M1454).
///
/// Placed in `features/sync/domain/usecases/` (not `lib/shared/`)
/// because it's specific to the sync feature's presence
/// subsystem — the palette + hash policy are presence-design
/// decisions, not general utilities. Matches the M1409
/// `collect_bulk_push_entries.dart` precedent for pure
/// sync-domain functions.
///
/// Same userId → same color always, so two devices for the same
/// user paint the same chiclet across devices and across app
/// restarts. The hash uses explicit char-code arithmetic rather
/// than Dart's `String.hashCode` because the latter is
/// implementation-defined and could differ between
/// dart-native / dart-web / future SDKs. We want one color per
/// user, forever.
///
/// The palette is 8 strong saturated colors that read clearly
/// with white label text (the overlay chiclet's foreground). No
/// pale yellows / pastels — those wash out at the 11-point font
/// size the chiclet uses. Brown is included as the 8th to widen
/// the perceptual gap from the other 7 (which cluster around
/// the warm + cool primaries).
const _palette = <String>[
  '#FF5722', // deep orange
  '#2196F3', // blue
  '#4CAF50', // green
  '#9C27B0', // purple
  '#E91E63', // pink
  '#00BCD4', // cyan
  '#FF9800', // orange
  '#795548', // brown
];

/// Returns a `#RRGGBB` hex color string deterministic over
/// [userId]. Empty input falls back to the first palette entry.
String peerColorFromUserId(String userId) {
  if (userId.isEmpty) return _palette[0];
  var sum = 0;
  for (final unit in userId.codeUnits) {
    sum = (sum + unit) & 0x7fffffff;
  }
  return _palette[sum % _palette.length];
}

/// Read-only view of the palette so tests + callers that need to
/// know the universe of possible colors can enumerate it.
List<String> get peerColorPalette => List.unmodifiable(_palette);
