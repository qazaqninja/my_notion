import 'dart:io';

import 'package:path/path.dart' as p;

/// One commit in a page's history.
class PageVersion {
  const PageVersion({
    required this.sha,
    required this.author,
    required this.timestamp,
    required this.message,
  });

  final String sha;
  final String author;
  final DateTime timestamp;
  final String message;
}

/// Git-backed page history reader. If the vault is not a git repo, [list]
/// returns an empty list and [showAt] throws StateError — callers should
/// surface a "vault isn't a git repo" message.
///
/// Each commit record is separated by NUL (`-z`) and the fields within a
/// record are tab-separated, so commit messages containing newlines or
/// pipes don't confuse parsing.
class PageHistory {
  const PageHistory();

  static final _nul = String.fromCharCode(0);

  /// True iff [vaultRoot] contains a `.git/` directory.
  Future<bool> isGitRepo(Directory vaultRoot) async {
    final dir = Directory(p.join(vaultRoot.path, '.git'));
    return dir.exists();
  }

  /// Returns commits that touch [relativePath]. Newest first.
  Future<List<PageVersion>> list(
    Directory vaultRoot,
    String relativePath, {
    int limit = 40,
  }) async {
    if (!await isGitRepo(vaultRoot)) return const [];
    final r = await Process.run(
      'git',
      [
        'log',
        '-z',
        '--pretty=tformat:%H%x09%an%x09%aI%x09%s',
        '--max-count=$limit',
        '--',
        relativePath,
      ],
      workingDirectory: vaultRoot.path,
    );
    if (r.exitCode != 0) return const [];
    final stdout = r.stdout as String;
    if (stdout.isEmpty) return const [];
    final entries = stdout.split(_nul);
    final out = <PageVersion>[];
    for (final raw in entries) {
      if (raw.isEmpty) continue;
      final parts = raw.split('\t');
      if (parts.length < 4) continue;
      DateTime ts;
      try {
        ts = DateTime.parse(parts[2]);
      } catch (_) {
        ts = DateTime.fromMillisecondsSinceEpoch(0);
      }
      out.add(PageVersion(
        sha: parts[0],
        author: parts[1],
        timestamp: ts,
        message: parts[3],
      ));
    }
    return out;
  }

  /// Returns the file contents at [sha]. Throws if not a git repo.
  Future<String> showAt(
    Directory vaultRoot,
    String relativePath,
    String sha,
  ) async {
    if (!await isGitRepo(vaultRoot)) {
      throw StateError('Not a git repository: ${vaultRoot.path}');
    }
    final r = await Process.run(
      'git',
      ['show', '$sha:$relativePath'],
      workingDirectory: vaultRoot.path,
    );
    if (r.exitCode != 0) {
      throw StateError('git show $sha:$relativePath failed: ${r.stderr}');
    }
    return r.stdout as String;
  }
}
