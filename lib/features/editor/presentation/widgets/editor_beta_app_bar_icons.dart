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
    EditorBetaAppBarAction.moveToTrash => Icons.delete_outline,
  };
}
