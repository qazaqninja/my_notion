import 'dart:io';

import 'package:path/path.dart' as p;

/// Probes [vaultRoot] for [relativePath]; if a file already lives there,
/// appends ` (N)` to the basename until a free slot is found. Falls
/// back to an epoch-ms suffix beyond 999.
///
/// Use this from any code path that writes a new page directly to disk
/// (importers, URL bookmarks, the new-page bloc handler). The atomic
/// tmp → rename used by VaultFsDatasource silently overwrites an
/// existing file at the destination — without this disambiguation,
/// dropping a `Notes.md` next to an existing `Notes.md` quietly erases
/// the prior page's contents.
///
/// [relativePath] is a path relative to [vaultRoot] (e.g. `Inbox/Foo.md`).
/// Returns the same relative-path form so callers can splice it into a
/// summary without further string surgery.
Future<String> uniqueRelativePath(
  Directory vaultRoot,
  String relativePath,
) async {
  if (!await File(p.join(vaultRoot.path, relativePath)).exists()) {
    return relativePath;
  }
  final folder = p.dirname(relativePath);
  final base = p.basenameWithoutExtension(relativePath);
  final ext = p.extension(relativePath);
  for (var n = 2; n < 1000; n++) {
    final candidate = '$base ($n)$ext';
    final rel =
        folder == '.' ? candidate : p.join(folder, candidate);
    if (!await File(p.join(vaultRoot.path, rel)).exists()) return rel;
  }
  final ts = DateTime.now().millisecondsSinceEpoch;
  final candidate = '$base ($ts)$ext';
  return folder == '.' ? candidate : p.join(folder, candidate);
}
