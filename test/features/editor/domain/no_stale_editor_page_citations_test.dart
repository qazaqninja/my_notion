import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1777 (post-D30d archaeology slice 2): sweep the remaining
  // `editor_page.dart` doc-comment citations from
  // lib/features/editor/domain/*. Follows the M1773 convention —
  // drop the deleted filename, keep the `_funcName` / case-label
  // / D-fp / M-milestone refs. 10 citations across 9 files.
  // M1778 fix-forward: TS-04 nested group wrap (M1777 audit info).
  group('lib/features/editor/domain/ stale citations', () {
    group('directory-wide scan', () {
      test('no `editor_page.dart` substring in any domain file', () {
        final dir = Directory('lib/features/editor/domain');
        final offenders = <String>[];
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          if (source.contains('editor_page.dart')) {
            offenders.add(entity.path);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'M1777: lib/features/editor/domain/* should not cite the '
              'deleted EditorPage source by filename; rephrase to keep '
              '`_funcName` / case-label / D-fp / M-milestone provenance.',
        );
      });
    });
  });
}
