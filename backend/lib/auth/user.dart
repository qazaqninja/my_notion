/// Auth-layer User entity. Matches the columns in the `users` table from
/// the E2 initial migration (M1288). Immutable + value-equal so it can
/// flow through repository / service boundaries without surprise mutation.
class User {
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id; // ULID
  final String email;
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
