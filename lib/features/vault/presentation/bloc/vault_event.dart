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
