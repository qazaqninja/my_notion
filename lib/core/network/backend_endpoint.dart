/// E57 — single-source-of-truth for the V2 backend endpoint. Three
/// consumers today: `app.dart` constructs HttpSyncRepository +
/// HttpFormsRepository with the HTTP base URL; `editor_page.dart`'s
/// EditorSyncWsMount opens a multiplayer WebSocket against the WS
/// variant; and the editor kebab's "Copy form link" action builds
/// the public form URL via [publicFormUrl].
///
/// When E14+ Settings exposes a user-configurable backend, both
/// constants will read from a stored value; the [publicFormUrl]
/// helper already takes the base URL as a parameter so it adopts
/// any override automatically.
library;

/// HTTP base URL the backend serves auth + sync + forms on.
const String kBackendHttpBaseUrl = 'http://localhost:8080';

/// WebSocket base URL the backend serves multiplayer subs on. Same
/// host+port as [kBackendHttpBaseUrl] with the scheme swapped to
/// `ws` (or `wss` once HTTPS lands).
const String kBackendWsBaseUrl = 'ws://localhost:8080';

/// Public-form URL a visitor opens to fill out the form-bearing
/// page at [pageUlid]. Submissions POST back to
/// `<backendBaseUrl>/forms/<pageUlid>/submit` (the E48 handler) and
/// land in the per-page submissions table (E49).
///
/// A trailing slash on [backendBaseUrl] is tolerated and stripped
/// so the joined string never contains `//`.
String publicFormUrl({
  required String backendBaseUrl,
  required String pageUlid,
}) {
  final base = backendBaseUrl.endsWith('/')
      ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
      : backendBaseUrl;
  return '$base/forms/$pageUlid';
}
