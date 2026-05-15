import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/vault_dirs.dart';

class VaultExporter {
  const VaultExporter();

  /// Copies every vault content file from [src] (recursively) to [dest],
  /// preserving relative paths. Skips standard ignored dirs + .trash so
  /// trashed content doesn't bleed into the export.
  ///
  /// File-type policy: keeps `.md`, `.database.yaml`, and any
  /// non-dotfile under `attachments/` (images, PDFs, audio, etc.).
  /// Other top-level non-markdown files (e.g. `.DS_Store`, random
  /// scratch files outside attachments/) are skipped so the export
  /// stays portable.
  ///
  /// Returns the number of files copied.
  Future<int> export({required Directory src, required Directory dest}) async {
    if (!src.existsSync()) {
      throw ArgumentError('Source vault not found: ${src.path}');
    }
    await dest.create(recursive: true);
    int copied = 0;
    await for (final entity in _walk(src)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: src.path);
      if (!_keep(rel)) continue;
      final target = File(p.join(dest.path, rel));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
      copied++;
    }
    return copied;
  }

  static const _ignoredDirs = kIgnoredVaultDirs;

  Stream<FileSystemEntity> _walk(Directory dir) async* {
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (_ignoredDirs.contains(name)) continue;
        yield* _walk(entity);
      } else if (entity is File) {
        yield entity;
      }
    }
  }

  /// Decide whether to copy a file based on its vault-relative path.
  /// .md and .database.yaml always go. Anything inside an `attachments/`
  /// folder (at any depth, not just vault root) also goes so embedded
  /// images / PDFs survive — per-folder attachments are a common
  /// pattern (e.g. `Customers/attachments/logo.png`) that the old
  /// "segments.first == 'attachments'" check silently dropped.
  static bool _keep(String relativePath) {
    final basename = p.basename(relativePath);
    if (basename.endsWith('.md')) return true;
    if (basename == '.database.yaml') return true;
    if (basename.startsWith('.')) return false;
    final segments = p.split(relativePath);
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'attachments') return true;
    }
    return false;
  }
}
