import '../../vault/domain/entities/vault_tree.dart';

/// Returns the parent folder of [relativePath], or `''` for top-level
/// (vault root) files. Mirrors the legacy inline
/// `lastIndexOf('/')` computation; pulled into the domain
/// layer at M1753 so the D-fp25 move-to-folder port can build its
/// "drop the current folder from the chooser" guard without
/// duplicating the logic.
String currentFolderOf(String relativePath) {
  final slash = relativePath.lastIndexOf('/');
  if (slash < 0) return '';
  return relativePath.substring(0, slash);
}

/// Walks [tree] depth-first and returns every [VaultFolder]'s
/// `relativePath` as a unique, alphabetically-sorted list. Files are
/// skipped. Duplicate paths (defensive — should never happen in a
/// well-formed tree but YAGNI bites if drift fixtures shift) collapse
/// to a single entry.
///
/// Drop-in replacement for the inline `walk` closure in the legacy
/// `_moveToFolder` handler. Lives in the
/// editor domain layer since the "list every folder for a Move-to
/// chooser" semantic is editor-specific — VaultTree itself only
/// promises the structural recursion.
List<String> collectVaultFolders(VaultTree tree) {
  final folders = <String>{};
  void walk(VaultNode n) {
    if (n is VaultFolder) {
      folders.add(n.relativePath);
      for (final c in n.children) {
        walk(c);
      }
    }
  }

  for (final n in tree.topLevel) {
    walk(n);
  }
  return folders.toList()..sort();
}
