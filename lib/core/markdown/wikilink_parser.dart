/// `[[ULID]]` wikilink locator. ULIDs are Crockford base32, 26 chars.
class Wikilink {
  const Wikilink({required this.ulid, required this.start, required this.end});

  /// 26-char ULID inside the brackets.
  final String ulid;

  /// Inclusive character offset of the opening `[`.
  final int start;

  /// Exclusive offset after the closing `]]`.
  final int end;

  @override
  String toString() => 'Wikilink($ulid @ $start..$end)';

  @override
  bool operator ==(Object other) =>
      other is Wikilink && other.ulid == ulid && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(ulid, start, end);
}

class WikilinkParser {
  const WikilinkParser._();

  static final _re = RegExp(r'\[\[([0-9A-Z]{26})\]\]');

  static List<Wikilink> find(String body) {
    return [
      for (final m in _re.allMatches(body))
        Wikilink(ulid: m.group(1)!, start: m.start, end: m.end),
    ];
  }
}
