/// User-visible label for the word-count goal frontmatter field.
/// Mirrors the legacy `editor_page.dart:_setWordGoal` plural rule —
/// only `n == 1` triggers the singular "word"; `0 words` matches the
/// legacy plural-for-zero choice.
String wordGoalLabel(int n) {
  return n == 1 ? '$n word' : '$n words';
}

/// Outcome of running [wordGoalActionFor] against a raw text input
/// and the optional existing frontmatter scalar. The caller switches
/// on the result to dispatch the matching `EditorBloc` event.
enum WordGoalAction {
  /// Nothing to do — empty input + no existing field.
  noop,

  /// Drop the existing `goal:` frontmatter row.
  remove,

  /// Input couldn't be parsed as an integer >= 1.
  invalid,

  /// Input equals the existing rawScalar (after trim); no event
  /// needed but the caller may want to SnackBar a confirmation.
  noopAlreadySet,

  /// Insert a new `goal:` row with the parsed integer.
  add,

  /// Update the existing `goal:` row's rawScalar + value.
  edit,
}

/// Pure-Dart planner for the D-fp21 set-goal port (M1745). Takes the
/// raw `picked` string from the prompt + the existing rawScalar (if
/// any) and returns the action the caller should dispatch.
///
/// Branches:
/// - empty `picked` + null `existing` → [WordGoalAction.noop]
/// - empty `picked` + present `existing` → [WordGoalAction.remove]
/// - `picked` non-numeric or parsed `n < 1` → [WordGoalAction.invalid]
/// - parsed `n` matches `existing.trim()` → [WordGoalAction.noopAlreadySet]
/// - parsed `n` + null `existing` → [WordGoalAction.add]
/// - parsed `n` + present `existing` (differing) → [WordGoalAction.edit]
WordGoalAction wordGoalActionFor({
  required String picked,
  required String? existing,
}) {
  final trimmed = picked.trim();
  if (trimmed.isEmpty) {
    return existing == null ? WordGoalAction.noop : WordGoalAction.remove;
  }
  final n = int.tryParse(trimmed);
  if (n == null || n < 1) return WordGoalAction.invalid;
  if (existing != null && existing.trim() == '$n') {
    return WordGoalAction.noopAlreadySet;
  }
  return existing == null ? WordGoalAction.add : WordGoalAction.edit;
}
