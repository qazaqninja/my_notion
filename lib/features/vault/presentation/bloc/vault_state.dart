import 'package:equatable/equatable.dart';

import '../../data/workspace_config.dart';
import '../../domain/entities/vault_tree.dart';

sealed class VaultState extends Equatable {
  const VaultState();
  @override
  List<Object?> get props => [];
}

class VaultInitial extends VaultState {
  const VaultInitial();
}

class VaultPicking extends VaultState {
  const VaultPicking();
}

class VaultLoading extends VaultState {
  const VaultLoading({this.rootPath});
  final String? rootPath;
  @override
  List<Object?> get props => [rootPath];
}

class VaultLoaded extends VaultState {
  const VaultLoaded({
    required this.rootPath,
    required this.tree,
    required this.expandedFolders,
    required this.pageCount,
    this.workspace = const WorkspaceConfig(),
  });

  final String rootPath;
  final VaultTree tree;
  final Set<String> expandedFolders;
  final int pageCount;
  final WorkspaceConfig workspace;

  VaultLoaded copyWith({
    String? rootPath,
    VaultTree? tree,
    Set<String>? expandedFolders,
    int? pageCount,
    WorkspaceConfig? workspace,
  }) {
    return VaultLoaded(
      rootPath: rootPath ?? this.rootPath,
      tree: tree ?? this.tree,
      expandedFolders: expandedFolders ?? this.expandedFolders,
      pageCount: pageCount ?? this.pageCount,
      workspace: workspace ?? this.workspace,
    );
  }

  @override
  List<Object?> get props =>
      [rootPath, tree, expandedFolders, pageCount, workspace.name, workspace.icon, workspace.favorites];
}

class VaultError extends VaultState {
  const VaultError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
