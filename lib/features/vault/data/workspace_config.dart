import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A single local user known to the vault. Names are referenced by the
/// `person` / `created_by` / `last_edited_by` column types and stamped
/// into frontmatter by the editor at save time.
class WorkspaceUser {
  const WorkspaceUser({required this.name, this.email, this.isDefault = false});

  /// Display name. Required.
  final String name;

  /// Optional contact email — surfaced in person-chip tooltips later.
  final String? email;

  /// When true, this user is picked as the workspace's "current user"
  /// for auto-stamping. Exactly zero or one user is expected to carry
  /// the flag; if none, the first entry is used.
  final bool isDefault;

  WorkspaceUser copyWith({String? name, String? email, bool? isDefault}) =>
      WorkspaceUser(
        name: name ?? this.name,
        email: email ?? this.email,
        isDefault: isDefault ?? this.isDefault,
      );
}

/// Vault-root `.quill.yaml`. Carries top-of-tree workspace preferences
/// that aren't per-page (workspace name + icon, favorites list, etc.).
/// Read once on vault load; rewritten verbatim when changed via
/// `WorkspaceConfig.save`.
class WorkspaceConfig {
  const WorkspaceConfig({
    this.name,
    this.icon,
    this.favorites = const [],
    this.sidebarOrder,
    this.sidebarHidden = const [],
    this.users = const [],
  });

  /// Display name override. When null, the sidebar derives from the
  /// vault folder's basename.
  final String? name;

  /// Emoji or single-char glyph for the workspace badge.
  final String? icon;

  /// Pinned page ULIDs in user-chosen order.
  final List<String> favorites;

  /// Sidebar section order override. When non-null, the sidebar renders
  /// sections in this sequence (unknown names ignored; missing names
  /// appended at the end in their canonical order).
  /// Read from `.quill.yaml`'s `sidebar.order: [...]`. Valid section
  /// names: `favorites`, `recent`, `workspace`, `databases`, `more`.
  final List<String>? sidebarOrder;

  /// Sidebar section names that the user has chosen to hide. Same
  /// vocabulary as [sidebarOrder]. Read from
  /// `.quill.yaml`'s `sidebar.hidden: [...]`.
  final List<String> sidebarHidden;

  /// Known local users of the vault. Read from `.quill.yaml`'s
  /// `users: [...]` list. The first entry whose `default: true` flag
  /// is set (or the first entry overall when none are flagged) drives
  /// the "current user" name used to auto-stamp `created_by:` and
  /// `last_edited_by:` on save.
  final List<WorkspaceUser> users;

  /// The current user's display name, or null when no users are
  /// declared in the workspace config.
  String? get currentUserName {
    if (users.isEmpty) return null;
    for (final u in users) {
      if (u.isDefault) return u.name;
    }
    return users.first.name;
  }

  WorkspaceConfig copyWith({
    String? name,
    String? icon,
    List<String>? favorites,
    List<String>? sidebarOrder,
    List<String>? sidebarHidden,
    List<WorkspaceUser>? users,
  }) {
    return WorkspaceConfig(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      favorites: favorites ?? this.favorites,
      sidebarOrder: sidebarOrder ?? this.sidebarOrder,
      sidebarHidden: sidebarHidden ?? this.sidebarHidden,
      users: users ?? this.users,
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
      List<String>? sidebarOrder;
      List<String> sidebarHidden = const [];
      final sb = doc['sidebar'];
      if (sb is YamlMap) {
        final order = sb['order'];
        if (order is YamlList) {
          sidebarOrder = [for (final s in order) '$s'];
        }
        final hidden = sb['hidden'];
        if (hidden is YamlList) {
          sidebarHidden = [for (final s in hidden) '$s'];
        }
      }
      final usersNode = doc['users'];
      final users = <WorkspaceUser>[];
      if (usersNode is YamlList) {
        for (final entry in usersNode) {
          if (entry is YamlMap) {
            final n = entry['name'];
            if (n == null) continue;
            users.add(WorkspaceUser(
              name: '$n',
              email: entry['email'] != null ? '${entry['email']}' : null,
              isDefault: entry['default'] == true,
            ));
          } else {
            users.add(WorkspaceUser(name: '$entry'));
          }
        }
      }
      return WorkspaceConfig(
        name: name,
        icon: icon,
        favorites: favorites,
        sidebarOrder: sidebarOrder,
        sidebarHidden: sidebarHidden,
        users: users,
      );
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
    final hasSidebar =
        (sidebarOrder != null && sidebarOrder!.isNotEmpty) ||
            sidebarHidden.isNotEmpty;
    if (hasSidebar) {
      buf.writeln('sidebar:');
      if (sidebarOrder != null && sidebarOrder!.isNotEmpty) {
        buf.writeln('  order:');
        for (final s in sidebarOrder!) {
          buf.writeln('    - $s');
        }
      }
      if (sidebarHidden.isNotEmpty) {
        buf.writeln('  hidden:');
        for (final s in sidebarHidden) {
          buf.writeln('    - $s');
        }
      }
    }
    if (users.isNotEmpty) {
      buf.writeln('users:');
      for (final u in users) {
        buf.writeln('  - name: ${u.name}');
        if (u.email != null) buf.writeln('    email: ${u.email}');
        if (u.isDefault) buf.writeln('    default: true');
      }
    }
    final file = File(p.join(vaultRoot.path, '.quill.yaml'));
    await file.writeAsString(buf.isEmpty ? '' : buf.toString());
  }
}
