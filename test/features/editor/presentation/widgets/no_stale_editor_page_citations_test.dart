import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1783 (post-D30d archaeology slice 4): sweep the 3 stale
  // `editor_page.dart` doc-comment citations across editor
  // presentation widgets — find_bar, source_view,
  // mobile_editor_toolbar. Mirrors the M1773/M1777/M1781
  // convention.
  group('editor widgets stale citations', () {
    group('explicit-enumeration scan', () {
      test('no `editor_page.dart` substring in widgets triplet', () {
        final files = <File>[
          File('lib/features/editor/presentation/widgets/find_bar.dart'),
          File('lib/features/editor/presentation/widgets/source_view.dart'),
          File(
            'lib/features/editor/presentation/widgets/mobile_editor_toolbar.dart',
          ),
        ];
        final offenders = <String>[];
        for (final f in files) {
          if (f.readAsStringSync().contains('editor_page.dart')) {
            offenders.add(f.path);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'M1783: editor presentation widgets should not cite the '
              'deleted EditorPage source by filename; rephrase per the '
              'M1773 convention.',
        );
      });
    });
  });
}
