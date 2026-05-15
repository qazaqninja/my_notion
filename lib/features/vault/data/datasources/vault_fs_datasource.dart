import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import '../../../../core/markdown/frontmatter_parser.dart';
import '../../../../core/vault_dirs.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../domain/entities/page.dart';

/// Filesystem-backed datasource for the vault. Reads/writes `.md` files,
/// keeps frontmatter byte-identical when unedited (via [FrontmatterParser]),
/// and writes atomically (tmp → rename).
///
/// [fs] is injectable so tests can swap to a [MemoryFileSystem]. Defaults to
/// `LocalFileSystem` in production.
class VaultFsDatasource {
  VaultFsDatasource({required this.ulids, FileSystem? fs})
      : fs = fs ?? const LocalFileSystem();

  final UlidGenerator ulids;
  final FileSystem fs;

  static const _ignoredDirs = kIgnoredVaultDirs;
  static const _markdownExt = '.md';

  /// Walk [root] recursively, emitting one [Page] per markdown file.
  /// A single malformed file (e.g. invalid YAML, transient read error)
  /// is logged and skipped rather than aborting the whole reindex —
  /// the old behaviour would emit a `VaultError` on the very first
  /// broken file and leave the user with an empty index.
  Stream<Page> scan(Directory root) async* {
    await for (final entity in _walk(root)) {
      if (entity is File && p.extension(entity.path) == _markdownExt) {
        try {
          yield await readOne(entity, vaultRoot: root);
        } catch (e, st) {
          // Per-file parse failures are logged and skipped — vault
          // scans must survive one malformed .md (M712).
          // ignore: avoid_print
          print('vault scan: skipping ${entity.path} — $e\n$st');
        }
      }
    }
  }

  Stream<FileSystemEntity> _walk(Directory dir) async* {
    final entries = dir.listSync();
    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (_ignoredDirs.contains(name)) continue;
        yield* _walk(entity);
      } else if (entity is File) {
        // Skip dotfiles (e.g. .DS_Store).
        if (name.startsWith('.')) continue;
        yield entity;
      }
    }
  }

  /// Read one markdown file and assemble a [Page]. ULID priority:
  /// frontmatter `id` → generated.
  Future<Page> readOne(File file, {required Directory vaultRoot}) async {
    final raw = await file.readAsString();
    final parsed = FrontmatterParser.parse(raw);
    final stat = await file.stat();
    final relative = p.relative(file.path, from: vaultRoot.path);

    final fmId = parsed.frontmatter.id;
    final ulid = fmId ?? ulids.generate();
    final title = parsed.frontmatter.title ?? p.basenameWithoutExtension(file.path);

    return Page(
      ulid: ulid,
      relativePath: relative,
      title: title,
      frontmatter: parsed.frontmatter,
      body: parsed.body,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    );
  }

  /// Atomic write — serialise then `rename` from a `.tmp` sibling. Preserves
  /// the original YAML block if it wasn't edited (see [FrontmatterParser]).
  Future<void> write(Page page, {required Directory vaultRoot}) async {
    final absPath = p.join(vaultRoot.path, page.relativePath);
    final target = fs.file(absPath);
    await target.parent.create(recursive: true);

    final doc = ParsedMarkdown(frontmatter: page.frontmatter, body: page.body);
    final serialised = FrontmatterParser.serialise(doc);

    // Atomic write: write to tmp then rename.
    final tmpPath = '$absPath.tmp';
    final tmp = fs.file(tmpPath);
    await tmp.writeAsString(serialised, flush: true);
    await tmp.rename(absPath);
  }
}

/// Convenience that resolves the system's home-directory shorthand and uses
/// the platform's [LocalFileSystem]. Production-only.
String expandUserPath(String path) {
  if (!path.startsWith('~/')) return path;
  final home = io.Platform.environment['HOME'] ?? io.Platform.environment['USERPROFILE'];
  if (home == null) return path;
  return p.join(home, path.substring(2));
}
