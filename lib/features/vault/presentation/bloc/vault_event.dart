import 'package:equatable/equatable.dart';

sealed class VaultEvent extends Equatable {
  const VaultEvent();
  @override
  List<Object?> get props => [];
}

/// Open a directory picker and load whatever the user chooses.
class PickVault extends VaultEvent {
  const PickVault();
}

/// Load a previously-known vault path on app boot.
class LoadFromPath extends VaultEvent {
  const LoadFromPath(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

class ToggleFolder extends VaultEvent {
  const ToggleFolder(this.relativePath);
  final String relativePath;
  @override
  List<Object?> get props => [relativePath];
}

class ReindexVault extends VaultEvent {
  const ReindexVault();
}

/// Fired by the [VaultWatcher] when external changes are detected on disk.
/// Triggers an in-place reindex that keeps the same [VaultLoaded] state
/// (no `VaultLoading` flash) and preserves expandedFolders.
class RefreshFromDisk extends VaultEvent {
  const RefreshFromDisk();
}

/// Create a new top-level page in the vault. [folderPath] is relative to
/// the vault root (empty string for root). The bloc returns the new ULID
/// via [onCreated] so the UI can navigate to the editor.
class CreatePage extends VaultEvent {
  const CreatePage({
    required this.title,
    this.folderPath = '',
    this.onCreated,
  });
  final String title;
  final String folderPath;
  final void Function(String ulid)? onCreated;
  @override
  List<Object?> get props => [title, folderPath];
}

/// Move a page to `.trash/<YYYY-MM>/<original-name>.md`. The page row is
/// removed from Drift (the `.trash` folder is in the ignored dirs list,
/// so a subsequent reindex would also drop it). Restoration is manual —
/// future work will surface a "Trash" view in settings.
class MoveToTrash extends VaultEvent {
  const MoveToTrash(this.ulid);
  final String ulid;
  @override
  List<Object?> get props => [ulid];
}

/// Toggle a page in the workspace's `favorites:` list. Adds if absent,
/// removes if present. Writes through to `.quill.yaml`.
class ToggleFavorite extends VaultEvent {
  const ToggleFavorite(this.ulid);
  final String ulid;
  @override
  List<Object?> get props => [ulid];
}

/// Move a page's .md file into [targetFolder] (relative to vault root,
/// empty = root). The page's ULID stays the same so wikilinks are
/// unaffected. No-op if the move would be to the same folder.
class MovePage extends VaultEvent {
  const MovePage({required this.ulid, required this.targetFolder});
  final String ulid;
  final String targetFolder;
  @override
  List<Object?> get props => [ulid, targetFolder];
}

/// Copy a page to a new .md with a fresh ULID and a `(copy)` title suffix.
/// Defaults to the source page's parent folder; pass [targetFolder] to
/// override (empty string = vault root). Used both for context-menu
/// "Duplicate" and for "New from template" where the source lives in
/// `Templates/` and the copy lands at root.
class DuplicatePage extends VaultEvent {
  const DuplicatePage(
    this.ulid, {
    this.targetFolder,
    this.titleOverride,
    this.onCreated,
  });
  final String ulid;

  /// Folder for the duplicate, relative to vault root. `null` = same as
  /// source. Empty string = vault root.
  final String? targetFolder;

  /// Use this title instead of "<source title> (copy)".
  final String? titleOverride;

  final void Function(String newUlid)? onCreated;
  @override
  List<Object?> get props => [ulid, targetFolder, titleOverride];
}

/// Drop the current vault association: SQLite is wiped, the saved
/// last-vault preference is cleared, and the state transitions back
/// to VaultInitial so the picker re-appears. Files on disk are not
/// touched.
class CloseVault extends VaultEvent {
  const CloseVault();
}
