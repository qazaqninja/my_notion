/// Decoded intent of a single click on the WYSIWYG editor, used to
/// drive the `BlockSelectionCubit`. Pure-Dart enum so the
/// interpretation logic is unit-testable without touching Flutter's
/// pointer event types.
enum BlockSelectionGestureIntent {
  /// Click on empty space (no nodeId) — clear the selection.
  clear,

  /// Cmd/Ctrl+Click on a block — toggle that block's membership.
  toggle,

  /// Shift+Click on a block — extend the selection to span from the
  /// last-clicked block to this one.
  extend,

  /// Plain click on a block (no modifiers) — replace the selection
  /// with just that block. (Caller can also opt to clear when the
  /// editor's text-caret semantics conflict; v1 ships with replace.)
  replace,

  /// No-op — the click should pass through to super_editor's normal
  /// caret handling (e.g., when a modifier is held but no block was
  /// hit, or unrecognized modifier combos).
  passthrough,
}

/// Interpret a single click event into a [BlockSelectionGestureIntent].
///
/// Parameters mirror what `EditorBetaPage` can extract from a
/// `PointerDownEvent` + `HardwareKeyboard.instance`:
/// - [nodeId] — the block id under the click (null when the click
///   missed the document layout entirely).
/// - [isPrimaryShortcutPressed] — Cmd on macOS, Ctrl on
///   Linux/Windows.
/// - [isShiftPressed] — Shift key state.
///
/// Contract:
/// - Missing [nodeId] → [BlockSelectionGestureIntent.clear] (clicking
///   off the document clears any multi-selection).
/// - Shift + primary → [BlockSelectionGestureIntent.extend] (range
///   from last anchor).
/// - Primary alone → [BlockSelectionGestureIntent.toggle].
/// - Plain (no modifiers) → [BlockSelectionGestureIntent.replace].
/// - Shift alone → [BlockSelectionGestureIntent.passthrough] (super
///   editor's own shift-click-to-extend-caret handles this).
BlockSelectionGestureIntent interpretBlockClick({
  required String? nodeId,
  required bool isPrimaryShortcutPressed,
  required bool isShiftPressed,
}) {
  if (nodeId == null) return BlockSelectionGestureIntent.clear;
  if (isPrimaryShortcutPressed && isShiftPressed) {
    return BlockSelectionGestureIntent.extend;
  }
  if (isPrimaryShortcutPressed) {
    return BlockSelectionGestureIntent.toggle;
  }
  if (isShiftPressed) {
    return BlockSelectionGestureIntent.passthrough;
  }
  return BlockSelectionGestureIntent.replace;
}
