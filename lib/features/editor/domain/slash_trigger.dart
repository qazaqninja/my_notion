/// Pure-Dart helpers describing when the `/` slash menu should open,
/// stay open, or dismiss given a caret position in a source string.
///
/// D23 of the super_editor migration extracts these decisions so the
/// existing `SourceView` widget and the upcoming WYSIWYG keyboard
/// listener inside `EditorBetaPage` can share identical semantics
/// without one of them re-implementing the heuristics.
///
/// All three functions are O(1) in the string length except for the
/// query-span scan in [slashShouldDismiss], which is bounded by the
/// trigger-to-caret distance (typically <= 32 chars before the user
/// commits or dismisses).
library;

/// True when typing a `/` at `caret` opens the slash menu.
///
/// The slash menu is a writing-flow affordance, not a URL inserter:
/// opens at column 0 or after whitespace; never inside a word so
/// `https://example.com` and `path/segment` don't trigger it.
bool slashShouldOpen({required String text, required int caret}) {
  if (caret < 1 || caret > text.length) return false;
  if (text[caret - 1] != '/') return false;
  if (caret == 1) return true;
  final prev = text[caret - 2];
  return prev == '\n' || prev == ' ' || prev == '\t';
}

/// Substring typed between the trigger and the current caret.
///
/// `triggerStart` is the offset immediately after the `/` (so
/// `slashShouldOpen` returning true sets it to `caret`). Returns the
/// empty string when the caret is exactly at the trigger.
String slashQueryBetween({
  required String text,
  required int triggerStart,
  required int caret,
}) {
  if (caret < triggerStart || triggerStart < 0 || caret > text.length) {
    return '';
  }
  return text.substring(triggerStart, caret);
}

/// True when the menu should be dismissed given the current selection.
///
/// Dismisses when:
/// - the caret moved before the trigger (user backspaced past `/`);
/// - the trigger is no longer inside the text (text shrank under it);
/// - the query span contains a space or newline (word boundary
///   committed the slash menu typing into ordinary prose).
bool slashShouldDismiss({
  required String text,
  required int triggerStart,
  required int caret,
}) {
  if (triggerStart < 0 || triggerStart > text.length) return true;
  if (caret < triggerStart) return true;
  final between = text.substring(triggerStart, caret);
  return between.contains(' ') || between.contains('\n');
}
