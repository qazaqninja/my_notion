/// Pure-Dart enumeration of the actions that surface on the
/// `EditorBetaPage` AppBar — pulled into the domain layer at M1700 so
/// the inclusion/exclusion rules can be unit-tested independently of
/// the widget tree.
///
/// Wire-up scheduled for the next slice: the AppBar build path in
/// `editor_beta_page.dart` will iterate [editorBetaAppBarActions] and
/// render an `IconButton` / `PopupMenuItem` per action. Today the
/// AppBar still constructs each `IconButton` inline; this enum is the
/// stable surface area future D-fp ports can plug into without
/// growing the imperative button list further.
enum EditorBetaAppBarAction {
  /// Dispatches `SyncFetchFileRequested` for the open page; visible
  /// only when the SyncBloc is authed to the v2 backend.
  pullFromServer(tooltip: 'Pull from server'),

  /// Toggles the FindBar overlay (D-fp4).
  findInPage(tooltip: 'Find in page'),

  /// Routes the current page through the OS share sheet (D-fp3).
  share(tooltip: 'Share'),

  /// Writes `[[<ulid>]]` to the clipboard (D-fp5, M1696).
  copyLink(tooltip: 'Copy [[link]] to this page'),

  /// Writes the bare ULID to the clipboard. D-fp6 port from legacy
  /// `editor_page.dart` case `'copy-ulid'`.
  copyUlid(tooltip: 'Copy ULID'),

  /// Writes the absolute filesystem path to the clipboard. D-fp7 port
  /// from legacy `editor_page.dart` case `'copy-path'`. Built via
  /// `vaultAbsolutePath(rootPath: …, relativePath: …)` so the join
  /// rules stay centralised.
  copyPath(tooltip: 'Copy file path'),

  /// Duplicates the page (frontmatter + body) into a sibling file
  /// with a fresh ULID; navigates the editor to the copy. D-fp8 port
  /// from legacy `editor_page.dart` case `'duplicate'` (dispatches the
  /// existing `DuplicatePage` VaultBloc event).
  duplicate(tooltip: 'Duplicate page'),

  /// Opens the page's `.md` file in the OS file browser (Finder /
  /// Files / Explorer). D-fp9 port from legacy `editor_page.dart`
  /// case `'reveal'`. Routes through the `Reveal.show()` platform
  /// helper at `lib/core/platform/reveal.dart`.
  reveal(tooltip: 'Reveal in OS file browser'),

  /// Renames the on-disk `.md` filename via the existing
  /// `RenamePage` VaultBloc event; the page's ULID + wikilinks
  /// survive. D-fp10 port from legacy `editor_page.dart` case
  /// `'rename'`. Sanitised via `sanitizedBasename(input)` so the
  /// toast preview matches the actual filename on disk.
  rename(tooltip: 'Rename file…'),

  /// Moves the file to `.trash/` + tombstones the server row when
  /// authed (D-fp1).
  moveToTrash(tooltip: 'Move to trash');

  const EditorBetaAppBarAction({required this.tooltip});

  /// Material `IconButton.tooltip` / `PopupMenuItem.toolTip` label.
  final String tooltip;
}

/// Returns the AppBar actions in the order they should appear, with
/// auth-gated entries (currently only [EditorBetaAppBarAction.pullFromServer])
/// filtered out when `isAuthed` is false. The order mirrors the
/// existing AppBar layout — Pull, Find, Share, Copy-link, Copy-ULID,
/// Move-to-trash — so a downstream widget can map directly to icons /
/// menu rows without re-sorting.
Iterable<EditorBetaAppBarAction> editorBetaAppBarActions({
  required bool isAuthed,
}) sync* {
  if (isAuthed) yield EditorBetaAppBarAction.pullFromServer;
  yield EditorBetaAppBarAction.findInPage;
  yield EditorBetaAppBarAction.share;
  yield EditorBetaAppBarAction.copyLink;
  yield EditorBetaAppBarAction.copyUlid;
  yield EditorBetaAppBarAction.copyPath;
  yield EditorBetaAppBarAction.duplicate;
  yield EditorBetaAppBarAction.reveal;
  yield EditorBetaAppBarAction.rename;
  yield EditorBetaAppBarAction.moveToTrash;
}
