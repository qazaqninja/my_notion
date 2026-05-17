import 'package:flutter/services.dart';

/// Discrete actions the Find-in-page bar reacts to from keyboard
/// shortcuts in the editor surface. Used as the return value of
/// [parseFindInPageKey] so the calling SuperEditorKeyboardAction
/// wrapper (slice 4b) can dispatch to the right `_BetaEditorShellState`
/// method (`_toggleFindBar` / `_onFindNext` / `_onFindPrev`).
///
/// Notion / VSCode bindings:
/// - Cmd+F → open the Find bar (and focus the TextField)
/// - Cmd+G → next match (wraps from last back to first)
/// - Cmd+Shift+G → previous match (wraps from first back to last)
/// - Escape → close the Find bar (no modifier required)
enum FindInPageKeyIntent {
  /// Cmd+F (Ctrl+F on Linux/Windows). Opens the Find bar.
  open,

  /// Cmd+G. Advances to the next match.
  next,

  /// Cmd+Shift+G. Steps back to the previous match.
  previous,

  /// Escape. Closes the Find bar.
  close,

  /// The key event isn't a find-in-page shortcut. Caller should fall
  /// through to super_editor's default handling.
  none,
}

/// Pure-Dart key-event parser for the Find-in-page shortcuts. Returns
/// the matched [FindInPageKeyIntent] or [FindInPageKeyIntent.none].
///
/// Modifier flags are caller-supplied (rather than read off
/// `HardwareKeyboard.instance` here) so the parser stays unit-testable
/// without touching global keyboard state — same pattern as
/// [parseBlockDeleteKey] + [parseHeadingConversionKey] + siblings.
///
/// Only [KeyDownEvent] and [KeyRepeatEvent] match — [KeyUpEvent]
/// always returns [FindInPageKeyIntent.none] so a held-then-released
/// shortcut doesn't double-fire.
///
/// Slice 4a of the D-fp4 Find-in-page port (M1636). Slice 4b wires
/// this into _BetaEditorShellState's SuperEditor keyboardActions array.
FindInPageKeyIntent parseFindInPageKey({
  required KeyEvent keyEvent,
  required bool isShiftPressed,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return FindInPageKeyIntent.none;
  }
  final key = keyEvent.logicalKey;

  // Escape closes regardless of modifier — matches Notion / VSCode.
  if (key == LogicalKeyboardKey.escape) {
    return FindInPageKeyIntent.close;
  }

  if (!isPrimaryShortcutPressed) return FindInPageKeyIntent.none;

  if (key == LogicalKeyboardKey.keyF) {
    if (isShiftPressed) return FindInPageKeyIntent.none;
    return FindInPageKeyIntent.open;
  }
  if (key == LogicalKeyboardKey.keyG) {
    return isShiftPressed
        ? FindInPageKeyIntent.previous
        : FindInPageKeyIntent.next;
  }
  return FindInPageKeyIntent.none;
}
