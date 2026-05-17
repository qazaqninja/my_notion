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
  const FrontmatterProbe._({
    this.ulid,
    this.isPublic = false,
    this.publicPasswordHash,
    this.hasForms = false,
    this.formsRef,
  });

  /// Probe [body]'s YAML frontmatter for the v2-backend-relevant
  /// fields (id, public, public_password, forms). Lines outside the
  /// `---\n…\n---` block are ignored; missing fields default to safe
  /// off/null values.
  factory FrontmatterProbe.fromBody(String body) {
    // Frontmatter block: starts with `---\n` and ends with `\n---` or
    // `---\n` further down. Anything outside is skipped.
    final block = _extractBlock(body);
    if (block == null) return const FrontmatterProbe._();
    String? ulid;
    var isPublic = false;
    String? publicPasswordHash;
    var hasForms = false;
    String? formsRef;
    for (final line in block.split('\n')) {
      final m = RegExp(r'^([a-zA-Z_][\w-]*)\s*:\s*(.*?)\s*$').firstMatch(line);
      if (m == null) continue;
      final key = m.group(1)!;
      final value = m.group(2)!.replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
      if (key == 'id' && _isUlid(value)) ulid = value;
      if (key == 'public' && (value == 'true' || value == 'yes')) {
        isPublic = true;
      }
      // E43: `public_password:` carries a bcrypt hash. The Flutter
      // client computes the hash before uploading; backend never
      // sees the plaintext. We only care about the value being a
      // syntactically-valid bcrypt hash so a typo'd password
      // doesn't silently bypass the check.
      if (key == 'public_password' && _isBcryptHash(value)) {
        publicPasswordHash = value;
      }
      // E47: `forms:` flags the page as carrying a form definition
      // that POST /forms/<ulid>/submit will accept. Any non-empty
      // value flips hasForms; F5 also records the value when it
      // looks like a relpath (contains `.database.yaml`) so the
      // route layer can resolve the linked schema.
      if (key == 'forms' && value.isNotEmpty) {
        hasForms = true;
        if (value.endsWith('.database.yaml')) {
          formsRef = value;
        }
      }
    }
    return FrontmatterProbe._(
      ulid: ulid,
      isPublic: isPublic,
      publicPasswordHash: publicPasswordHash,
      hasForms: hasForms,
      formsRef: formsRef,
    );
  }

  /// 26-char Crockford-base32 ULID parsed from `id:`. Null when the
  /// frontmatter is missing or the value isn't a valid ULID.
  final String? ulid;

  /// True when `public: true` (or `yes`) appears in the frontmatter
  /// — the `GET /public/<ulid>` route gates on this flag.
  final bool isPublic;

  /// E43 — bcrypt hash of the public-page password, when set. Null
  /// means the public page is reachable without an unlock cookie.
  final String? publicPasswordHash;

  /// E47 — true when the page's frontmatter declares a `forms:` field
  /// with a non-empty value, indicating that
  /// `POST /forms/<ulid>/submit` should accept submissions for this
  /// page. The schema itself is resolved separately via [formsRef].
  final bool hasForms;

  /// F5 — when `forms:` was a relpath (e.g. `customers.database.yaml`)
  /// rather than a bare `true`, this is that path. Null for the
  /// bare-truthy case — submissions then run against an empty schema
  /// (legacy "any non-empty body" fallback).
  final String? formsRef;

  /// True when `public: true` AND the page has been gated behind a
  /// password.
  bool get isPasswordProtected =>
      isPublic && publicPasswordHash != null;

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

  /// True iff [s] looks like a bcrypt hash (`$2a$<cost>$<salt+hash>`).
  /// Defensive — a malformed value lets us refuse to gate the page
  /// rather than locking it with garbage.
  static bool _isBcryptHash(String s) {
    return RegExp(r'^\$2[abxy]\$\d{2}\$[./A-Za-z0-9]{53}$').hasMatch(s);
  }
}
