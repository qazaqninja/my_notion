import 'dart:io';

import 'package:path/path.dart' as p;

class VaultExporter {
  const VaultExporter();

  /// Copies every `.md` and `.database.yaml` file from [src] (recursively)
  /// to [dest], preserving relative paths. Skips standard ignored dirs.
  /// Returns the number of files copied.
  Future<int> export({required Directory src, required Directory dest}) async {
    if (!src.existsSync()) {
      throw ArgumentError('Source vault not found: ${src.path}');
    }
    await dest.create(recursive: true);
    int copied = 0;
    await for (final entity in _walk(src)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (!_keep(base)) continue;
      final rel = p.relative(entity.path, from: src.path);
      final target = File(p.join(dest.path, rel));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
      copied++;
    }
    return copied;
  }

  static const _ignoredDirs = {'.git', '.obsidian', 'node_modules', '_meta', '.dart_tool', '.idea'};

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

  static bool _keep(String basename) {
    if (basename.startsWith('.') && basename != '.database.yaml') return false;
    if (basename.endsWith('.md')) return true;
    if (basename == '.database.yaml') return true;
    return false;
  }
}
