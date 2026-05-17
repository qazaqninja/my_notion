/// Auth-layer User entity. Matches the columns in the `users` table from
/// the E2 initial migration (M1288). Immutable + value-equal so it can
/// flow through repository / service boundaries without surprise mutation.
class User {
  /// Construct a User entity hydrated from a `users` row.
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  /// Stable ULID — primary key on the `users` table.
  final String id; // ULID

  /// Normalized lowercase email — the unique secondary key.
  final String email;

  /// Server-set creation timestamp (UTC).
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.email == email &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, email, createdAt);

  @override
  String toString() => 'User(id: $id, email: $email)';
}
