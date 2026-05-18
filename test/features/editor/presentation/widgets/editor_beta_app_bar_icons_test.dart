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

    test('copyPath → Icons.folder_outlined (D-fp7 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.copyPath),
        Icons.folder_outlined,
      );
    });

    test('duplicate → Icons.copy_outlined (D-fp8 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.duplicate),
        Icons.copy_outlined,
      );
    });

    test('reveal → Icons.folder_open_outlined (D-fp9 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.reveal),
        Icons.folder_open_outlined,
      );
    });

    test('rename → Icons.drive_file_rename_outline (D-fp10 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.rename),
        Icons.drive_file_rename_outline,
      );
    });

    test('publishToggle → Icons.public_outlined (D-fp11 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.publishToggle),
        Icons.public_outlined,
      );
    });

    test('pageHistory → Icons.history (D-fp12 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.pageHistory), Icons.history);
    });

    test('setFont → Icons.font_download_outlined (D-fp14 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.setFont),
        Icons.font_download_outlined,
      );
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
