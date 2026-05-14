import 'package:ulid/ulid.dart';

/// Thin wrapper around `package:ulid` so we have a single seam to swap or
/// stub (tests inject a deterministic generator).
///
/// The wrapping enforces uppercase Crockford output. `package:ulid`
/// returns lowercase strings, which collides with the inline wikilink
/// regex (`[0-9A-HJKMNP-TV-Z]{26}`) and the fixtures that ship uppercase
/// IDs. Forcing uppercase keeps newly created pages addressable from
/// wikilinks and matches the existing on-disk convention.
class UlidGenerator {
  const UlidGenerator();
  String generate() => Ulid().toString().toUpperCase();
}
