import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/vault_watcher.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VaultWatcher', () {
    late Directory tmp;
    late VaultWatcher watcher;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quill_watcher_test_');
      watcher = VaultWatcher(debounce: const Duration(milliseconds: 50));
    });

    tearDown(() async {
      await watcher.dispose();
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('fires once for a .md write (debounced)', () async {
      await watcher.watch(tmp);
      var ticks = 0;
      final sub = watcher.changes.listen((_) => ticks++);
      addTearDown(sub.cancel);

      // Burst of writes: should debounce to one tick.
      for (var i = 0; i < 5; i++) {
        await File(p.join(tmp.path, 'note$i.md')).writeAsString('# hi $i');
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(ticks, equals(1));
    });

    test('ignores .tmp atomic-write siblings', () async {
      await watcher.watch(tmp);
      var ticks = 0;
      final sub = watcher.changes.listen((_) => ticks++);
      addTearDown(sub.cancel);

      await File(p.join(tmp.path, 'note.md.tmp')).writeAsString('x');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(ticks, equals(0));
    });

    test('ignores files inside .git', () async {
      final git = Directory(p.join(tmp.path, '.git'));
      await git.create();
      await watcher.watch(tmp);
      var ticks = 0;
      final sub = watcher.changes.listen((_) => ticks++);
      addTearDown(sub.cancel);

      await File(p.join(git.path, 'HEAD')).writeAsString('ref: x');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(ticks, equals(0));
    });

    test('stop() halts further events', () async {
      await watcher.watch(tmp);
      await watcher.stop();
      var ticks = 0;
      final sub = watcher.changes.listen((_) => ticks++);
      addTearDown(sub.cancel);

      await File(p.join(tmp.path, 'after.md')).writeAsString('hi');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(ticks, equals(0));
    });
  });
}
