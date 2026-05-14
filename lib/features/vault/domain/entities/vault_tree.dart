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
  });
  final String ulid;
}

/// Recursive tree mirroring the on-disk structure. The root is implicit
/// (the vault directory itself); [topLevel] contains its immediate children.
class VaultTree {
  const VaultTree({required this.topLevel});
  final List<VaultNode> topLevel;

  static const VaultTree empty = VaultTree(topLevel: []);
}
