/// Probe the YAML frontmatter block of a markdown body for the two
/// fields the v2 backend cares about: `id:` (ULID, page identifier) and
/// `public:` (boolean — when true the page is reachable at
/// `GET /public/<ulid>` regardless of owner).
///
/// Why not a full YAML parser? Backend reads bodies dozens of times per
/// upsert; the two fields we need have a deterministic single-line shape
/// (`id: 01HXABC…`, `public: true`). A regex pass over the frontmatter
/// block is faster, has no dependency footprint, and matches Quill's
/// own `frontmatter_parser.dart` which preserves raw scalars verbatim.
class FrontmatterProbe {
  const FrontmatterProbe._({this.ulid, this.isPublic = false});

  factory FrontmatterProbe.fromBody(String body) {
    // Frontmatter block: starts with `---\n` and ends with `\n---` or
    // `---\n` further down. Anything outside is skipped.
    final block = _extractBlock(body);
    if (block == null) return const FrontmatterProbe._();
    String? ulid;
    var isPublic = false;
    for (final line in block.split('\n')) {
      final m = RegExp(r'^([a-zA-Z_][\w-]*)\s*:\s*(.*?)\s*$').firstMatch(line);
      if (m == null) continue;
      final key = m.group(1)!;
      final value = m.group(2)!.replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
      if (key == 'id' && _isUlid(value)) ulid = value;
      if (key == 'public' && (value == 'true' || value == 'yes')) {
        isPublic = true;
      }
    }
    return FrontmatterProbe._(ulid: ulid, isPublic: isPublic);
  }

  final String? ulid;
  final bool isPublic;

  /// Extract the inner YAML block from a markdown body, or null if no
  /// frontmatter is present. Matches `^---\n…\n---\n?` at file start.
  static String? _extractBlock(String body) {
    final m = RegExp(r'^---\s*\n([\s\S]*?)\n---', multiLine: false)
        .firstMatch(body);
    return m?.group(1);
  }

  /// True iff [s] is a 26-char Crockford-base32 ULID. Matches the
  /// regex the Flutter client uses for inline wikilink chips.
  static bool _isUlid(String s) {
    return RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s);
  }
}
