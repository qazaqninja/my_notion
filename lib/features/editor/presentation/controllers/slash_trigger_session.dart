import '../../domain/slash_trigger.dart';

/// Owns the lifecycle of one slash-menu trigger across successive caret
/// updates. Consumers (`SourceView`, `EditorBetaPage`'s upcoming
/// super_editor listener) call [update] on every text/selection change
/// and the session emits at most one of [onOpen] / [onQuery] / [onDismiss]
/// per call based on the M1518 [slash_trigger] helpers.
///
/// Keeping the trigger-start coordinate in a separate object (vs a State
/// field) lets the WYSIWYG keyboard wiring share the exact behaviour
/// `SourceView` ships today without ferrying its private state across
/// widgets.
class SlashTriggerSession {
  /// Construct a fresh session with no active trigger.
  SlashTriggerSession();

  int? _triggerStart;

  /// True iff a `/` is currently waiting for query input.
  bool get hasActiveTrigger => _triggerStart != null;

  /// Caret-source-of-truth callback. Pass the document's plain text and
  /// the caret offset (single-cursor only — multi-selection consumers
  /// should call [reset] separately when expanding the selection).
  ///
  /// Exactly one of the three callbacks fires per call:
  /// - [onOpen]\(triggerOffset\) when a fresh `/` enters at a word boundary
  ///   (offset is the position of the `/` itself).
  /// - [onQuery]\(query\) when the caret advanced past an open trigger
  ///   without crossing whitespace.
  /// - [onDismiss]\(\) when an open trigger is invalidated (caret moved
  ///   before it, query span hit a space/newline, or the text shrank
  ///   under the trigger).
  void update({
    required String text,
    required int caret,
    required void Function(int triggerOffset) onOpen,
    required void Function() onDismiss,
    required void Function(String query) onQuery,
  }) {
    if (_triggerStart == null) {
      if (slashShouldOpen(text: text, caret: caret)) {
        _triggerStart = caret;
        onOpen(caret - 1);
      }
      return;
    }
    final start = _triggerStart!;
    if (slashShouldDismiss(text: text, triggerStart: start, caret: caret)) {
      _triggerStart = null;
      onDismiss();
      return;
    }
    onQuery(slashQueryBetween(text: text, triggerStart: start, caret: caret));
  }

  /// Clear the active trigger without firing any callback. Use when a
  /// caller knows the menu should be closed for an external reason
  /// (page navigation, multi-selection start, etc.).
  void reset() {
    _triggerStart = null;
  }
}
