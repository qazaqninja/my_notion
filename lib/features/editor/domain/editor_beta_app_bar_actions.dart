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

  /// Toggles the `public: true` frontmatter field so the page
  /// becomes (or stops being) reachable via the backend
  /// `GET /public/<ulid>` route. D-fp11 port from legacy
  /// `editor_page.dart` cases `'publish'` + `'unpublish'`. Password
  /// gating remains on the legacy editor for now.
  publishToggle(tooltip: 'Publish / unpublish'),

  /// Opens the [PageHistoryDialog] backed by `git log` on the
  /// current page's `.md` file. D-fp12 port from legacy
  /// `editor_page.dart` case `'history'`. Only useful when the vault
  /// is a git repo (the dialog itself reports "no git history" when
  /// not).
  pageHistory(tooltip: 'Page history (git log)'),

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
  yield EditorBetaAppBarAction.publishToggle;
  yield EditorBetaAppBarAction.pageHistory;
  yield EditorBetaAppBarAction.moveToTrash;
}

/// M1727 (D-fp13 kebab refactor slice 1): partition the AppBar
/// actions into a small "always-visible" set rendered as bare
/// IconButtons + a larger "secondary" set folded into a
/// PopupMenuButton kebab. The split mirrors the legacy editor's
/// "top of kebab vs. inside kebab" UX and addresses the visual
/// crowding observed once 12 D-fp actions all rendered as side-by-
/// side IconButtons.
///
/// **Top bar** (most frequent + destructive): pullFromServer,
/// findInPage, share, moveToTrash.
///
/// **Kebab**: copyLink, copyUlid, copyPath, duplicate, reveal,
/// rename, publishToggle, pageHistory.
///
/// Splitting in a pure-Dart helper (rather than at the widget tree)
/// keeps the visibility + ordering rules testable independently of
/// the AppBar build path. UI wire-up lands in slice 2.
bool isEditorBetaKebabAction(EditorBetaAppBarAction action) {
  return switch (action) {
    EditorBetaAppBarAction.pullFromServer ||
    EditorBetaAppBarAction.findInPage ||
    EditorBetaAppBarAction.share ||
    EditorBetaAppBarAction.moveToTrash =>
      false,
    EditorBetaAppBarAction.copyLink ||
    EditorBetaAppBarAction.copyUlid ||
    EditorBetaAppBarAction.copyPath ||
    EditorBetaAppBarAction.duplicate ||
    EditorBetaAppBarAction.reveal ||
    EditorBetaAppBarAction.rename ||
    EditorBetaAppBarAction.publishToggle ||
    EditorBetaAppBarAction.pageHistory =>
      true,
  };
}

/// The subset of [editorBetaAppBarActions] that renders as bare
/// IconButtons on the AppBar. Preserves the order from
/// [editorBetaAppBarActions].
Iterable<EditorBetaAppBarAction> editorBetaTopBarActions({
  required bool isAuthed,
}) =>
    editorBetaAppBarActions(isAuthed: isAuthed)
        .where((a) => !isEditorBetaKebabAction(a));

/// The subset of [editorBetaAppBarActions] that folds into the
/// PopupMenuButton kebab. Auth gating doesn't apply here today
/// (none of the kebab entries depend on `isAuthed`), but the
/// parameter is plumbed for future symmetry.
Iterable<EditorBetaAppBarAction> editorBetaKebabActions({
  required bool isAuthed,
}) =>
    editorBetaAppBarActions(isAuthed: isAuthed)
        .where(isEditorBetaKebabAction);
