import 'package:ulid/ulid.dart';

/// Thin wrapper around `package:ulid` so we have a single seam to swap or
/// stub (tests inject a deterministic generator).
class UlidGenerator {
  const UlidGenerator();
  String generate() => Ulid().toString();
}
