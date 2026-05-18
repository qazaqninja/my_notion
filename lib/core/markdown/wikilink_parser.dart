import 'package:meta/meta.dart';

/// `[[ULID]]` or `[[ULID#anchor]]` wikilink locator. ULIDs are
/// Crockford base32 (`0-9A-HJKMNP-TV-Z`), 26 chars — the renderer's
/// inline parser uses the same alphabet, so the indexer and renderer
/// agree on what counts as a link.
@immutable
class Wikilink {
  const Wikilink({
    required this.ulid,
    required this.start,
    required this.end,
    this.anchor,
  });

  /// 26-char ULID inside the brackets, stripped of any `#anchor`
  /// suffix. Relations index by ULID, anchors are display-only.
  final String ulid;

  /// Optional `#anchor` slug after the ULID. Drives in-page scroll
  /// in the renderer; null when the wikilink had no suffix.
  final String? anchor;

  /// Inclusive character offset of the opening `[`.
  final int start;

  /// Exclusive offset after the closing `]]`.
  final int end;

  @override
  String toString() => 'Wikilink($ulid${anchor == null ? '' : '#$anchor'} @ $start..$end)';

  @override
  bool operator ==(Object other) =>
      other is Wikilink &&
      other.ulid == ulid &&
      other.anchor == anchor &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(ulid, anchor, start, end);
}

class WikilinkParser {
  const WikilinkParser._();

  // Permissive `[0-9A-Z]` ULID character class: real ULIDs use the
  // Crockford alphabet (no I/L/O/U) but earlier test fixtures and
  // some externally-imported docs use the full uppercase range.
  // Accept both so previously-indexed relations don't silently
  // disappear. Anchor is the same `#section-slug` shape the
  // renderer's inline parser accepts.
  static final _re = RegExp(
      r'\[\[([0-9A-Z]{26})(?:#([a-z0-9][a-z0-9\-]*))?\]\]');

  static List<Wikilink> find(String body) {
    return [
      for (final m in _re.allMatches(body))
        Wikilink(
          ulid: m.group(1)!,
          anchor: m.group(2),
          start: m.start,
          end: m.end,
        ),
    ];
  }
}

/// Build the literal `[[ULID]]` / `[[ULID#anchor]]` form a Quill
/// editor pastes into the document and the renderer parses back via
/// [WikilinkParser.find]. Centralised so the format lives in one
/// place — adding a `>` flag or alt-text suffix later would only need
/// this helper to change.
///
/// `ulid` is **not** validated against the Crockford alphabet; the
/// caller is expected to pass a value sourced from a [Wikilink],
/// frontmatter `id:`, or `UlidGenerator.next()`. `anchor` is appended
/// after a literal `#` when non-null and non-empty; null / empty
/// `anchor` omits the `#` entirely so the bare-link round-trip stays
/// byte-identical.
String wikilinkLiteralFor({required String ulid, String? anchor}) {
  if (anchor == null || anchor.isEmpty) return '[[$ulid]]';
  return '[[$ulid#$anchor]]';
}
