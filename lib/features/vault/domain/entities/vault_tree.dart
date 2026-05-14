/// One node in the vault tree.
sealed class VaultNode {
  const VaultNode({required this.name, required this.relativePath});
  final String name;
  final String relativePath;
}

class VaultFolder extends VaultNode {
  const VaultFolder({
    required super.name,
    required super.relativePath,
    required this.children,
  });
  final List<VaultNode> children;
}

class VaultFile extends VaultNode {
  const VaultFile({
    required super.name,
    required super.relativePath,
    required this.ulid,
    this.icon,
  });
  final String ulid;

  /// Optional `icon:` value from the page's frontmatter. Currently only
  /// emoji glyphs are surfaced in the sidebar (paths / URLs require an
  /// async image load which isn't worth the cost for a 13px row).
  final String? icon;
}

/// Recursive tree mirroring the on-disk structure. The root is implicit
/// (the vault directory itself); [topLevel] contains its immediate children.
class VaultTree {
  const VaultTree({required this.topLevel});
  final List<VaultNode> topLevel;

  static const VaultTree empty = VaultTree(topLevel: []);
}
