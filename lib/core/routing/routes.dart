/// Centralised route path constants for the app's go_router routing
/// surface. All `context.go(...)` / `GoRouter.of(...).go(...)` /
/// `GoRoute(path: ...)` call sites should reference these constants
/// rather than inline string literals — keeps the canonical path in
/// one place and makes refactors safe (the analyzer flags any
/// remaining bare path strings on grep).
///
/// Introduced for the D28-D30 cutover prep (NV-03 carry-forward from
/// the D-fp1 / M1621 orchestrator audit). Other call sites — the
/// legacy `editor_page.dart` + `mobile_chrome.dart` +
/// `vault_shell_page.dart` + `app.dart` `redirect` callback +
/// `GoRoute` declarations — will be migrated incrementally as the
/// 1m-loop revisits each file.
abstract class Routes {
  /// `/` — the vault picker page (and the redirect target when no
  /// vault has been loaded yet).
  static const picker = '/';

  /// `/vault` — alias for the picker shown when the user manually
  /// requests vault re-selection from the sidebar.
  static const vault = '/vault';

  /// `/home` — the default vault landing page (recent-pages dashboard).
  static const home = '/home';

  /// `/databases` — the database index inside the vault shell.
  static const databases = '/databases';

  /// `/tags` — the tag index inside the vault shell.
  static const tags = '/tags';

  /// `/settings` — the settings page (Vault / Appearance / Sync /
  /// Forms / etc. panes).
  static const settings = '/settings';

  /// `/lab` — debug-only ComponentSheetPage. Allowed outside the
  /// vault-loaded gate (the redirect callback short-circuits when
  /// the matched location is `/lab`).
  static const lab = '/lab';

  /// Build the legacy `/editor/<ulid>` route, optionally with an
  /// `?anchor=<slug>` query parameter for in-page jump-to-block
  /// behaviour. Returns the bare path when [anchor] is null or empty
  /// — matches existing call-site interpolation for parity.
  ///
  /// No URI-encoding is applied to [anchor] for parity with existing
  /// call sites (`markdown_renderer.dart:4503` etc.). Callers passing
  /// untrusted values should encode upstream.
  static String editor(String ulid, {String? anchor}) {
    if (anchor == null || anchor.isEmpty) return '/editor/$ulid';
    return '/editor/$ulid?anchor=$anchor';
  }

  /// Build the beta `/editor-beta/<ulid>` route. Used by the
  /// `EditorBetaPage` route declaration in `app.dart` + any future
  /// direct nav into the beta editor.
  static String editorBeta(String ulid) => '/editor-beta/$ulid';

  /// Build the `/db/<dbId>` or `/db/<dbId>/<viewId>` route. Returns
  /// the bare two-segment form when [viewId] is null or empty. The
  /// double-route declaration in `app.dart` accepts both shapes.
  static String db(String dbId, {String? viewId}) {
    if (viewId == null || viewId.isEmpty) return '/db/$dbId';
    return '/db/$dbId/$viewId';
  }

  /// Build the `/settings/<section>` route used for deep-linking
  /// into a specific Settings pane (Vault / Appearance / Sync /
  /// Forms / etc.). Compare with the bare [settings] constant for
  /// the index page.
  static String settingsSection(String section) => '/settings/$section';
}
