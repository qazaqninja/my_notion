import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1773 (post-D30d archaeology cleanup slice 1): the legacy
  // `editor_page.dart` source was deleted at M1765. Doc-comment
  // citations that pointed at `editor_page.dart case 'X'` still
  // carried weight as port-lineage breadcrumbs but the filename
  // itself is now a dangling reference. Convention going forward:
  // keep the case-label (`'X'` is the actually-useful information
  // about what the legacy kebab key was) and any M-milestone /
  // D-fp number, drop the deleted filename. Git history holds the
  // full original source for anyone who wants the line-level diff.
  //
  // First slice: editor_beta_app_bar_actions.dart, which had 16
  // citations in enum doc comments.
  //
  // M1774 fix-forward: TS-04 group wrap (M1773 audit info finding).
  group('editor_beta_app_bar_actions.dart stale citations', () {
    test('has no `editor_page.dart` refs', () {
      final file = File(
        'lib/features/editor/domain/editor_beta_app_bar_actions.dart',
      );
      final source = file.readAsStringSync();
      expect(
        source.contains('editor_page.dart'),
        isFalse,
        reason:
            'M1773: legacy filename removed from enum doc comments — '
            'kept the case-label + D-fp / M-milestone refs; git history '
            'holds the full source.',
      );
    });
  });
}
