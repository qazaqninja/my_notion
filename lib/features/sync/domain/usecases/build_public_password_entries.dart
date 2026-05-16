import 'package:bcrypt/bcrypt.dart';

import '../../../vault/domain/entities/frontmatter_entry.dart';

/// E44 — pure function used by the editor's "Publish with password…"
/// flow.
///
/// Returns the pair of frontmatter entries that should be stamped into
/// a page so the backend's E43 public-route password gate kicks in:
///
///   public: true
///   public_password: &lt;bcrypt hash of [password]&gt;
///
/// The plaintext password never leaves the client; the bcrypt hash is
/// what the backend stores via the existing E43 sync upsert path.
///
/// Throws `ArgumentError` for empty passwords — defensive: an empty
/// password would still pass bcrypt but offers no real protection, and
/// the caller almost certainly wants to surface a UI error rather than
/// silently publish.
({FrontmatterEntry publicFlag, FrontmatterEntry passwordHash})
    buildPublicPasswordEntries(String password) {
  if (password.isEmpty) {
    throw ArgumentError.value(password, 'password', 'must not be empty');
  }
  // Cost 10 matches the backend's auth/password.dart default and
  // keeps the per-publish hash cost ~100 ms on a desktop — fast
  // enough to feel synchronous but not weak.
  final hash = BCrypt.hashpw(password, BCrypt.gensalt());
  return (
    publicFlag: const FrontmatterEntry(
      key: 'public',
      rawScalar: 'true',
      type: FrontmatterType.checkbox,
      value: true,
    ),
    passwordHash: FrontmatterEntry(
      key: 'public_password',
      // Quote the value — bcrypt hashes contain `$` which YAML
      // tolerates unquoted, but quoting keeps the raw round-trip
      // unambiguous and survives every parser we care about.
      rawScalar: '"$hash"',
      type: FrontmatterType.text,
      value: hash,
    ),
  );
}
