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
}
