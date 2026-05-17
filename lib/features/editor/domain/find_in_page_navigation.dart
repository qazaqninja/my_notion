import 'package:equatable/equatable.dart';
import 'package:super_editor/super_editor.dart';

import 'document_search.dart';

/// Build a super_editor [ChangeSelectionRequest] that expand-selects
/// the span occupied by [match]. The reason `'find-in-page'` lets
/// downstream listeners (caret anchors, scroll-into-view reactions)
/// distinguish a programmatic find-jump from a user click.
///
/// Slice 2 of the D-fp4 Find-in-Page port. Slice 3 wires the
/// EditorBetaPage UI to call `editor.execute([this request])` on
/// next/previous/goTo.
ChangeSelectionRequest selectionRequestForMatch(DocumentMatch match) {
  return ChangeSelectionRequest(
    DocumentSelection(
      base: DocumentPosition(
        nodeId: match.nodeId,
        nodePosition: TextNodePosition(offset: match.start),
      ),
      extent: DocumentPosition(
        nodeId: match.nodeId,
        nodePosition: TextNodePosition(offset: match.end),
      ),
    ),
    SelectionChangeType.expandSelection,
    'find-in-page',
  );
}

/// Pure-Dart immutable cursor over a `List<DocumentMatch>` for the
/// Find-in-Page navigation surface in EditorBetaPage.
///
/// Each navigation op ([next], [previous], [goTo]) returns a fresh
/// [MatchCursor] with the updated [index]. Cycles wrap around — last
/// + next() → first; first + previous() → last (Notion / VSCode
/// convention). Out-of-bounds [goTo] returns `this`.
///
/// Holds [matches] as a constructor-supplied list; callers are
/// responsible for treating it as immutable (the [MatchCursor.initial]
/// factory wraps it in `List.unmodifiable` to enforce that locally).
class MatchCursor extends Equatable {
  /// Internal constructor — prefer [MatchCursor.empty] or
  /// [MatchCursor.initial].
  const MatchCursor({required this.matches, required this.index});

  /// Sentinel empty cursor: no matches, [index] is `-1`.
  factory MatchCursor.empty() => const MatchCursor(matches: [], index: -1);

  /// Build a cursor positioned at the first match (index 0) when
  /// [matches] is non-empty, or the empty sentinel otherwise. Wraps
  /// [matches] in `List.unmodifiable` so callers can't mutate the
  /// underlying list out from under the cursor.
  factory MatchCursor.initial(List<DocumentMatch> matches) {
    if (matches.isEmpty) return MatchCursor.empty();
    return MatchCursor(
      matches: List.unmodifiable(matches),
      index: 0,
    );
  }

  /// The full list of matches this cursor walks over.
  final List<DocumentMatch> matches;

  /// The active match index, or `-1` when [matches] is empty.
  final int index;

  /// True when no matches are tracked.
  bool get isEmpty => matches.isEmpty;

  /// Number of matches tracked.
  int get count => matches.length;

  /// The match at [index], or null when the cursor is empty / index
  /// is out of bounds.
  DocumentMatch? get current {
    if (isEmpty) return null;
    if (index < 0 || index >= matches.length) return null;
    return matches[index];
  }

  /// Advance to the next match, wrapping from last back to first.
  /// Returns the same cursor unchanged when empty.
  MatchCursor next() {
    if (isEmpty) return this;
    final n = (index + 1) % matches.length;
    return MatchCursor(matches: matches, index: n);
  }

  /// Move to the previous match, wrapping from first back to last.
  /// Returns the same cursor unchanged when empty.
  MatchCursor previous() {
    if (isEmpty) return this;
    final n = (index - 1 + matches.length) % matches.length;
    return MatchCursor(matches: matches, index: n);
  }

  /// Jump to [i]. Returns the same cursor unchanged when empty or
  /// when [i] is out of bounds (does NOT clamp — callers can detect
  /// the no-op via referential equality).
  MatchCursor goTo(int i) {
    if (isEmpty) return this;
    if (i < 0 || i >= matches.length) return this;
    return MatchCursor(matches: matches, index: i);
  }

  @override
  List<Object?> get props => [matches, index];
}
