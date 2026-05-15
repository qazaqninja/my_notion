import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/frontmatter_parser.dart';

/// A trashed file pending restore or hard-delete.
class TrashedItem {
  const TrashedItem({
    required this.path,
    required this.bucket,
    required this.title,
    required this.basename,
    this.ulid,
    this.mtimeMs = 0,
    this.emojiIcon,
  });

  /// Absolute path on disk.
  final String path;

  /// `YYYY-MM` folder inside .trash/.
  final String bucket;

  /// Title from frontmatter, or filename if no title.
  final String title;

  /// Basename including .md extension.
  final String basename;

  /// ULID from frontmatter, if present.
  final String? ulid;

  /// File mtime (millis since epoch) — the moment the trash move happened.
  final int mtimeMs;

  /// Plain emoji from the page's `icon:` frontmatter, if any. Asset
  /// paths and URLs are skipped so the trash dialog can render a 16px
  /// glyph without an async image load.
  final String? emojiIcon;
}

class TrashService {
  const TrashService();

  Future<List<TrashedItem>> list(Directory vaultRoot) async {
    final root = Directory(p.join(vaultRoot.path, '.trash'));
    if (!await root.exists()) return const [];
    final out = <TrashedItem>[];
    await for (final bucketDir in root.list()) {
      if (bucketDir is! Directory) continue;
      final bucket = p.basename(bucketDir.path);
      await for (final entity in bucketDir.list()) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        final basename = p.basename(entity.path);
        try {
          final raw = await entity.readAsString();
          final fm = FrontmatterParser.parse(raw).frontmatter;
          final stat = await entity.stat();
          final iconRaw = fm.find('icon')?.rawScalar.trim() ?? '';
          final emoji = iconRaw.isEmpty ||
                  iconRaw.length > 4 ||
                  iconRaw.contains('/') ||
                  iconRaw.startsWith('http')
              ? null
              : iconRaw;
          out.add(TrashedItem(
            path: entity.path,
            bucket: bucket,
            title: fm.title ?? p.basenameWithoutExtension(basename),
            basename: basename,
            ulid: fm.id,
            mtimeMs: stat.modified.millisecondsSinceEpoch,
            emojiIcon: emoji,
          ));
        } catch (_) {
          // Skip malformed files — never crash the trash listing.
        }
      }
    }
    out.sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    return out;
  }

  /// Move the file back to [vaultRoot]. Collision: suffix `-restored-N`.
  /// Returns the new absolute path so callers can re-index.
  Future<String> restore(TrashedItem item, Directory vaultRoot) async {
    final basename = item.basename;
    var dest = File(p.join(vaultRoot.path, basename));
    int n = 1;
    while (await dest.exists()) {
      final stem = p.basenameWithoutExtension(basename);
      final ext = p.extension(basename);
      dest = File(p.join(vaultRoot.path, '$stem-restored-$n$ext'));
      n++;
    }
    await File(item.path).rename(dest.path);
    return dest.path;
  }

  /// Permanently delete the file. Returns true on success.
  Future<bool> deleteForever(TrashedItem item) async {
    try {
      await File(item.path).delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
