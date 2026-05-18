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

    test('setGoal → Icons.flag_outlined (D-fp21 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.setGoal), Icons.flag_outlined);
    });

    test('exportMarkdown → Icons.file_download_outlined (D-fp22 port glyph)',
        () {
      expect(
        iconFor(EditorBetaAppBarAction.exportMarkdown),
        Icons.file_download_outlined,
      );
    });

    test('exportHtml → Icons.code (D-fp22 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.exportHtml), Icons.code);
    });

    test('printPage → Icons.print_outlined (D-fp23 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.printPage),
        Icons.print_outlined,
      );
    });

    test('setReminder → Icons.alarm (D-fp15 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.setReminder), Icons.alarm);
    });

    test('snoozeReminder → Icons.snooze (D-fp16 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.snoozeReminder), Icons.snooze);
    });

    test('clearReminder → Icons.alarm_off (D-fp16 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.clearReminder),
        Icons.alarm_off,
      );
    });

    test('copyBody → Icons.content_paste (D-fp17 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.copyBody),
        Icons.content_paste,
      );
    });

    test('copyPlain → Icons.text_snippet_outlined (D-fp18 port glyph)', () {
      expect(
        iconFor(EditorBetaAppBarAction.copyPlain),
        Icons.text_snippet_outlined,
      );
    });

    test('copyJson → Icons.data_object (D-fp18 port glyph)', () {
      expect(iconFor(EditorBetaAppBarAction.copyJson), Icons.data_object);
    });

    test('viewFormSubmissions → Icons.inbox_outlined (D-fp19 port glyph)',
        () {
      expect(
        iconFor(EditorBetaAppBarAction.viewFormSubmissions),
        Icons.inbox_outlined,
      );
    });

    test('copyFormLink → Icons.add_link (D-fp20 port glyph)', () {
      // Distinct from copyLink (Icons.link, M1696) — semantically
      // "compose a link to share with non-authors".
      expect(iconFor(EditorBetaAppBarAction.copyFormLink), Icons.add_link);
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
