import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1785 (post-D30d archaeology slice 5, FINAL): sweep the 32
  // remaining `editor_page.dart` doc-comment citations in
  // editor_beta_page.dart. Closes the entire post-D30d archaeology
  // arc (M1773 + M1777 + M1781 + M1783 + M1785). Convention:
  // `editor_page.dart[:NNN[-NNN]]` → `legacy editor`, dropping the
  // dangling filename + line numbers while preserving D-fp /
  // M-milestone / case-label / `_funcName` provenance.
  group('editor_beta_page.dart stale citations', () {
    group('full-file scan', () {
      test('no `editor_page.dart` substring anywhere', () {
        final file = File(
          'lib/features/editor/presentation/pages/editor_beta_page.dart',
        );
        final source = file.readAsStringSync();
        expect(
          source.contains('editor_page.dart'),
          isFalse,
          reason:
              'M1785: editor_beta_page.dart should not cite the deleted '
              'EditorPage source by filename; rephrase per the M1773 '
              'convention.',
        );
      });
    });
  });
}
