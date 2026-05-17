import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/strike_autoformat_reaction.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('StrikeAutoformatReaction.react', () {
    late MutableDocument document;
    late MutableDocumentComposer composer;
    late EditContext context;
    late _RecordingDispatcher dispatcher;
    const reaction = StrikeAutoformatReaction();

    setUp(() {
      document = MutableDocument(
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('~~strike~~')),
        ],
      );
      composer = MutableDocumentComposer();
      context = EditContext({
        Editor.documentKey: document,
        Editor.composerKey: composer,
      });
      dispatcher = _RecordingDispatcher();
    });

    test('no-op when selection is null', () {
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('no-op when selection is non-collapsed', () {
      composer.setSelectionWithReason(
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 10),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('no-op when active node is non-TextNode (HorizontalRule)', () {
      document
        ..deleteNodeAt(0)
        ..insertNodeAt(0, HorizontalRuleNode(id: 'hr1'));
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('no-op when caret is mid-span (no closing `~~` yet)', () {
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('dispatches DeleteContentRequest + InsertTextRequest with '
        'strikethroughAttribution when caret is at end of `~~strike~~`', () {
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 10),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests.length, 1);
      final batch = dispatcher.executedRequests.first;
      expect(batch.length, 2);
      expect(batch[0], isA<DeleteContentRequest>());
      expect(batch[1], isA<InsertTextRequest>());

      final delete = batch[0] as DeleteContentRequest;
      expect(delete.documentRange.start.nodeId, 'p1');
      expect(
        (delete.documentRange.start.nodePosition as TextNodePosition).offset,
        0,
      );
      expect(
        (delete.documentRange.end.nodePosition as TextNodePosition).offset,
        10,
      );

      final insert = batch[1] as InsertTextRequest;
      expect(insert.textToInsert, 'strike');
      expect(insert.attributions, contains(strikethroughAttribution));
    });
  });
}

/// Records every `execute(...)` call without forwarding. Same harness
/// pattern as `bold_autoformat_reaction_test.dart` /
/// `italic_autoformat_reaction_test.dart`.
class _RecordingDispatcher implements RequestDispatcher {
  final List<List<EditRequest>> executedRequests = [];

  @override
  void execute(List<EditRequest> requests) {
    executedRequests.add(List.unmodifiable(requests));
  }
}
