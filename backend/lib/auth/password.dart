import 'package:bcrypt/bcrypt.dart';

/// Password hashing wrapper around bcrypt — separate from the route handlers
/// so a future swap (e.g. argon2id) is one file's worth of churn.
///
/// Cost factor 12 is the standard balance between strength and CPU. Tune via
/// `BCRYPT_COST` env var only if a deploy actually needs it.
class PasswordHasher {
  const PasswordHasher({this.cost = 12});

  final int cost;

  /// Hash [plain] with a freshly-generated salt. Result is the full bcrypt
  /// modular crypt string (`$2b$12$…`) safe to store directly in the
  /// `users.password_hash` column.
  String hash(String plain) =>
      BCrypt.hashpw(plain, BCrypt.gensalt(logRounds: cost));

  /// Constant-time check: true iff [plain] hashes to [hashed].
  bool verify(String plain, String hashed) =>
      BCrypt.checkpw(plain, hashed);
}
