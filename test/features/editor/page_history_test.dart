import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/page_history.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_history_test_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('isGitRepo returns false for plain dirs', () async {
    expect(await const PageHistory().isGitRepo(tmp), isFalse);
  });

  test('list returns empty when vault is not a git repo', () async {
    final r = await const PageHistory().list(tmp, 'foo.md');
    expect(r, isEmpty);
  });

  test('list + showAt against a real tiny git repo', () async {
    // Skip on hosts without git on PATH.
    final which = await Process.run('which', ['git']);
    if (which.exitCode != 0) {
      markTestSkipped('git not on PATH');
      return;
    }
    await Process.run('git', ['init', '-q'], workingDirectory: tmp.path);
    await Process.run('git', ['config', 'user.email', 'test@example.com'],
        workingDirectory: tmp.path);
    await Process.run('git', ['config', 'user.name', 'Test'],
        workingDirectory: tmp.path);

    final file = File(p.join(tmp.path, 'note.md'));
    await file.writeAsString('v1\n');
    await Process.run('git', ['add', '.'], workingDirectory: tmp.path);
    await Process.run('git', ['commit', '-q', '-m', 'first'],
        workingDirectory: tmp.path);
    await file.writeAsString('v2\n');
    await Process.run('git', ['add', '.'], workingDirectory: tmp.path);
    await Process.run('git', ['commit', '-q', '-m', 'second\nwith newline'],
        workingDirectory: tmp.path);

    final history = const PageHistory();
    final commits = await history.list(tmp, 'note.md');
    expect(commits, hasLength(2));
    // Newest first.
    expect(commits.first.message, startsWith('second'));
    expect(commits.last.message, equals('first'));
    expect(commits.first.author, equals('Test'));

    final v1 = await history.showAt(tmp, 'note.md', commits.last.sha);
    expect(v1.trim(), equals('v1'));
    final v2 = await history.showAt(tmp, 'note.md', commits.first.sha);
    expect(v2.trim(), equals('v2'));
  });
}
