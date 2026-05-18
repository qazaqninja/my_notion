import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1781 (post-D30d archaeology slice 3): sweep the 6 remaining
  // `editor_page.dart` doc-comment citations that lived outside the
  // editor feature itself — cross-cutting references in app.dart,
  // core/, sync/, vault/, forms/. Mirrors the M1773 + M1777
  // convention (drop deleted filename, keep `_funcName` / case-label
  // / D-fp / M-milestone provenance).
  group('cross-cutting stale citations', () {
    group('directory-wide scan', () {
      test(
        'no `editor_page.dart` substring in app.dart, core/, '
        'features/sync/, features/vault/, features/forms/',
        () {
          final files = <File>[
            File('lib/app.dart'),
            File('lib/core/network/backend_endpoint.dart'),
            File('lib/core/routing/routes.dart'),
            File('lib/features/forms/domain/usecases/list_form_bearing_pages.dart'),
            File('lib/features/sync/presentation/editor_sync_ws_mount.dart'),
            File('lib/features/vault/domain/sanitized_basename.dart'),
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
                'M1781: cross-cutting files should not cite the deleted '
                'EditorPage source by filename; rephrase per the M1773 '
                'convention.',
          );
        },
      );
    });
  });
}
