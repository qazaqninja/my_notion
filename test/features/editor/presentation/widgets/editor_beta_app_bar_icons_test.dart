import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/editor_beta_app_bar_actions.dart';
import 'package:my_notion/features/editor/presentation/widgets/editor_beta_app_bar_icons.dart';

void main() {
  group('iconFor', () {
    test('pullFromServer → Icons.cloud_download_outlined', () {
      expect(
        iconFor(EditorBetaAppBarAction.pullFromServer),
        Icons.cloud_download_outlined,
      );
    });

    test('findInPage → Icons.search', () {
      expect(iconFor(EditorBetaAppBarAction.findInPage), Icons.search);
    });

    test('share → Icons.share_outlined', () {
      expect(iconFor(EditorBetaAppBarAction.share), Icons.share_outlined);
    });

    test('copyLink → Icons.link', () {
      expect(iconFor(EditorBetaAppBarAction.copyLink), Icons.link);
    });

    test('copyUlid → Icons.tag (D-fp6 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.copyUlid), Icons.tag);
    });

    test('moveToTrash → Icons.delete_outline', () {
      expect(
        iconFor(EditorBetaAppBarAction.moveToTrash),
        Icons.delete_outline,
      );
    });

    test('every enum value maps to a distinct IconData', () {
      final mapped = <IconData>{};
      for (final action in EditorBetaAppBarAction.values) {
        mapped.add(iconFor(action));
      }
      expect(
        mapped.length,
        EditorBetaAppBarAction.values.length,
        reason: 'each action should render with its own icon',
      );
    });
  });
}
