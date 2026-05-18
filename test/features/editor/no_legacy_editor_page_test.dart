import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // D30d (M1765): the legacy `EditorPage` source is removed. The
  // beta WYSIWYG editor (EditorBetaPage) closed full kebab parity at
  // M1755 (D-fp arc); the GoRoute fork collapsed at M1757 (D30b); the
  // fork-helper deleted at M1759 (D30c-a); the Settings toggle + root
  // provider deleted at M1761 (D30c-c); the EditorPreferencesCubit
  // family deleted at M1763 (D30c-b). After all of that, the legacy
  // page widget had zero remaining call sites — confirmed by a
  // pre-deletion grep showing ONE matching file (the source itself)
  // and zero `import .* editor_page.dart` statements anywhere in
  // lib/ or test/. This slice deletes the source.
  group('D30d deletion-guard', () {
    test('legacy editor_page.dart source is removed', () {
      final file = File(
        'lib/features/editor/presentation/pages/editor_page.dart',
      );
      expect(
        file.existsSync(),
        isFalse,
        reason: 'D30d: legacy EditorPage source deleted (zero call sites)',
      );
    });

    test('no live import of editor_page.dart in lib/', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final line in source.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ')) continue;
          if (trimmed.contains('editor_page.dart')) {
            hits.add('${entity.path}: $trimmed');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'D30d: no surviving import of legacy EditorPage in lib/',
      );
    });

    test('no live import of editor_page.dart in test/', () {
      final hits = <String>[];
      for (final entity in Directory('test').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final line in source.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('import ')) continue;
          if (trimmed.contains('editor_page.dart')) {
            hits.add('${entity.path}: $trimmed');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'D30d: no surviving import of legacy EditorPage in test/',
      );
    });
  });
}
