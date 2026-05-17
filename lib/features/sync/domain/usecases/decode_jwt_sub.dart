import 'dart:convert';

/// H4d-iii-d-ii — best-effort extraction of the `sub` (subject)
/// claim from a JWT.
///
/// Used by SyncState.userId so the editor's outbound presence path
/// (and any future per-user logic) can identify the current user
/// without a separate `/me` round-trip. The backend's auth
/// middleware (M1448 era) sets `sub` to the user's stable ULID at
/// login time.
///
/// Returns null on any failure mode:
///   - null / empty input
///   - not three dot-separated segments
///   - middle segment isn't valid base64url-decoded UTF-8 JSON
///   - decoded JSON isn't an object
///   - `sub` is missing or not a String
///
/// Pure function — no signature verification. The token is treated
/// as trusted because the backend issued it; this helper only
/// extracts a claim the client already received.
String? decodeJwtSub(String? token) {
  if (token == null || token.isEmpty) return null;
  final segments = token.split('.');
  if (segments.length != 3) return null;
  try {
    final padded = base64Url.normalize(segments[1]);
    final bytes = base64Url.decode(padded);
    final decoded = utf8.decode(bytes);
    final json = jsonDecode(decoded);
    if (json is! Map<String, Object?>) return null;
    final sub = json['sub'];
    if (sub is String && sub.isNotEmpty) return sub;
    return null;
  } catch (_) {
    return null;
  }
}
