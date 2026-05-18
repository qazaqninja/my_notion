import 'package:flutter/material.dart';

import '../../domain/editor_beta_app_bar_actions.dart';

/// Maps an [EditorBetaAppBarAction] enum value to the Material
/// `IconData` the AppBar's `IconButton` renders. Kept in the
/// presentation layer (so `package:flutter/material.dart` is allowed)
/// while [EditorBetaAppBarAction] itself stays pure-Dart in the
/// domain layer.
///
/// Pulled out of `_BetaEditorShellState._iconButtonFor` at M1707 so
/// the icon mapping is unit-testable without a widget tree.
IconData iconFor(EditorBetaAppBarAction action) {
  return switch (action) {
    EditorBetaAppBarAction.pullFromServer => Icons.cloud_download_outlined,
    EditorBetaAppBarAction.findInPage => Icons.search,
    EditorBetaAppBarAction.share => Icons.share_outlined,
    EditorBetaAppBarAction.copyLink => Icons.link,
    EditorBetaAppBarAction.copyUlid => Icons.tag,
    EditorBetaAppBarAction.copyPath => Icons.folder_outlined,
    EditorBetaAppBarAction.duplicate => Icons.copy_outlined,
    EditorBetaAppBarAction.reveal => Icons.folder_open_outlined,
    EditorBetaAppBarAction.rename => Icons.drive_file_rename_outline,
    EditorBetaAppBarAction.publishToggle => Icons.public_outlined,
    EditorBetaAppBarAction.pageHistory => Icons.history,
    EditorBetaAppBarAction.setFont => Icons.font_download_outlined,
    EditorBetaAppBarAction.setGoal => Icons.flag_outlined,
    EditorBetaAppBarAction.exportMarkdown => Icons.file_download_outlined,
    EditorBetaAppBarAction.exportHtml => Icons.code,
    EditorBetaAppBarAction.printPage => Icons.print_outlined,
    EditorBetaAppBarAction.setReminder => Icons.alarm,
    EditorBetaAppBarAction.snoozeReminder => Icons.snooze,
    EditorBetaAppBarAction.clearReminder => Icons.alarm_off,
    EditorBetaAppBarAction.copyBody => Icons.content_paste,
    EditorBetaAppBarAction.copyPlain => Icons.text_snippet_outlined,
    EditorBetaAppBarAction.copyJson => Icons.data_object,
    EditorBetaAppBarAction.copyFormLink => Icons.add_link,
    EditorBetaAppBarAction.viewFormSubmissions => Icons.inbox_outlined,
    EditorBetaAppBarAction.moveToTrash => Icons.delete_outline,
  };
}
