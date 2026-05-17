import 'package:equatable/equatable.dart';
import 'package:super_editor/super_editor.dart';

/// One substring match found inside a super_editor [Document] node.
///
/// Identifies the node that owns the match by [nodeId] and the
/// half-open `[start, end)` UTF-16 code-unit range within the node's
/// plain-text payload (`AttributedText.toPlainText()`).
///
/// Slice 1 of the D-fp4 Find-in-Page port. Slice 2 will translate
/// `DocumentMatch` values to super_editor `DocumentSelection`s via
/// `ChangeSelectionRequest` so found matches highlight + scroll into
/// view.
class DocumentMatch extends Equatable {
  /// Construct an immutable match spanning `[start, end)` in node
  /// [nodeId].
  const DocumentMatch({
    required this.nodeId,
    required this.start,
    required this.end,
  });

  /// The id of the [TextNode] this match lives in.
  final String nodeId;

  /// Inclusive start offset in the node's plain text.
  final int start;

  /// Exclusive end offset in the node's plain text.
  final int end;

  /// Number of UTF-16 code units covered by this match.
  int get length => end - start;

  @override
  List<Object?> get props => [nodeId, start, end];
}

/// Pure-Dart substring search over a super_editor [Document].
///
/// Walks every [TextNode] (paragraph, list-item, task, header
/// paragraphs — anything that extends `TextNode`) and emits one
/// [DocumentMatch] per occurrence of [query]. Non-text blocks (image,
/// hr, etc.) are skipped silently — they have no plain-text payload.
///
/// Case-insensitive by default; pass [caseSensitive] `true` to opt
/// in. Returns an empty list when [query] is empty.
///
/// The scan advances by 1 between matches, so overlapping matches
/// (`'aa'` in `'aaaa'` → three matches) are emitted in order. This
/// mirrors Notion's find-in-page behaviour where each occurrence is
/// independently jumpable.
List<DocumentMatch> findMatches({
  required Document document,
  required String query,
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return const [];
  final needle = caseSensitive ? query : query.toLowerCase();
  final out = <DocumentMatch>[];
  for (final node in document) {
    if (node is! TextNode) continue;
    final raw = node.text.toPlainText();
    final hay = caseSensitive ? raw : raw.toLowerCase();
    var idx = 0;
    while (true) {
      final found = hay.indexOf(needle, idx);
      if (found < 0) break;
      out.add(
        DocumentMatch(
          nodeId: node.id,
          start: found,
          end: found + needle.length,
        ),
      );
      idx = found + 1;
    }
  }
  return out;
}
