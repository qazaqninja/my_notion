import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Vault-root `.quill.yaml`. Carries top-of-tree workspace preferences
/// that aren't per-page (workspace name + icon, favorites list, etc.).
/// Read once on vault load; rewritten verbatim when changed via
/// `WorkspaceConfig.save`.
class WorkspaceConfig {
  const WorkspaceConfig({
    this.name,
    this.icon,
    this.favorites = const [],
  });

  /// Display name override. When null, the sidebar derives from the
  /// vault folder's basename.
  final String? name;

  /// Emoji or single-char glyph for the workspace badge.
  final String? icon;

  /// Pinned page ULIDs in user-chosen order.
  final List<String> favorites;

  WorkspaceConfig copyWith({
    String? name,
    String? icon,
    List<String>? favorites,
  }) {
    return WorkspaceConfig(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      favorites: favorites ?? this.favorites,
    );
  }

  /// Reads from `<vaultRoot>/.quill.yaml`. Missing file → defaults.
  static Future<WorkspaceConfig> load(Directory vaultRoot) async {
    final file = File(p.join(vaultRoot.path, '.quill.yaml'));
    if (!await file.exists()) return const WorkspaceConfig();
    try {
      final raw = await file.readAsString();
      final dynamic doc = loadYaml(raw);
      if (doc is! YamlMap) return const WorkspaceConfig();
      final ws = doc['workspace'];
      String? name;
      String? icon;
      if (ws is YamlMap) {
        if (ws['name'] != null) name = '${ws['name']}';
        if (ws['icon'] != null) icon = '${ws['icon']}';
      }
      final favs = doc['favorites'];
      final favorites = <String>[
        if (favs is YamlList)
          for (final f in favs) '$f',
      ];
      return WorkspaceConfig(name: name, icon: icon, favorites: favorites);
    } catch (_) {
      return const WorkspaceConfig();
    }
  }

  /// Writes the config to `<vaultRoot>/.quill.yaml`, preserving only the
  /// fields we know about. Other top-level keys (if any) are dropped —
  /// the file is intended to be entirely managed by Quill.
  Future<void> save(Directory vaultRoot) async {
    final buf = StringBuffer();
    if (name != null || icon != null) {
      buf.writeln('workspace:');
      if (name != null) buf.writeln('  name: $name');
      if (icon != null) buf.writeln('  icon: $icon');
    }
    if (favorites.isNotEmpty) {
      buf.writeln('favorites:');
      for (final f in favorites) {
        buf.writeln('  - $f');
      }
    }
    final file = File(p.join(vaultRoot.path, '.quill.yaml'));
    await file.writeAsString(buf.isEmpty ? '' : buf.toString());
  }
}
