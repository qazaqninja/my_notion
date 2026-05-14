import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/quick_capture.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_qc_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
  });

  test('first capture creates the file with frontmatter + entry',
      () async {
    final rel = await QuickCapture.append('hello world', vault);
    expect(rel, 'Inbox/Quick capture.md');
    final body =
        await File(p.join(vault.path, 'Inbox/Quick capture.md'))
            .readAsString();
    expect(body, contains('title: Quick capture'));
    expect(body, contains('Append-only log.'));
    expect(body, contains('hello world'));
    // Bullet line uses the local-time format `- YYYY-MM-DD HH:MM:SS · text`.
    expect(body, contains(RegExp(r'- \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} · hello world')));
  });

  test('second capture lands at the top', () async {
    await QuickCapture.append('first', vault);
    // small sleep so timestamps differ (though we don't check that here).
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await QuickCapture.append('second', vault);
    final body =
        await File(p.join(vault.path, 'Inbox/Quick capture.md'))
            .readAsString();
    final firstIdx = body.indexOf('first');
    final secondIdx = body.indexOf('second');
    expect(secondIdx, isNonNegative);
    expect(firstIdx, isNonNegative);
    expect(secondIdx, lessThan(firstIdx));
  });

  test('empty capture throws FormatException', () async {
    await expectLater(
      () => QuickCapture.append('   ', vault),
      throwsA(isA<FormatException>()),
    );
  });

  test('does not duplicate frontmatter on a subsequent capture',
      () async {
    await QuickCapture.append('a', vault);
    await QuickCapture.append('b', vault);
    final body =
        await File(p.join(vault.path, 'Inbox/Quick capture.md'))
            .readAsString();
    // Exactly one frontmatter delimiter pair → `---` appears at the
    // start of file + once at the end of frontmatter.
    expect('---'.allMatches(body).length, 2);
  });
}
