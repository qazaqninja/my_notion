import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/bold_autoformat_reaction.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('BoldAutoformatReaction.react', () {
    late MutableDocument document;
    late MutableDocumentComposer composer;
    late EditContext context;
    late _RecordingDispatcher dispatcher;
    const reaction = BoldAutoformatReaction();

    setUp(() {
      document = MutableDocument(
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('**bold**')),
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
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('no-op when the active node is a non-TextNode '
        '(HorizontalRule)', () {
      // Rebuild document with an HR as the only node.
      document.deleteNodeAt(0);
      document.insertNodeAt(0, HorizontalRuleNode(id: 'hr1'));
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

    test('no-op when the caret has not just typed a closing `**`', () {
      // Caret mid-word: detector should refuse to fire.
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
        SelectionReason.userInteraction,
      );
      reaction.react(context, dispatcher, []);
      expect(dispatcher.executedRequests, isEmpty);
    });

    test('dispatches DeleteContentRequest + InsertTextRequest when the '
        'caret is just past the closing `**`', () {
      composer.setSelectionWithReason(
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'p1',
            nodePosition: TextNodePosition(offset: 8),
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
        8,
      );

      final insert = batch[1] as InsertTextRequest;
      expect(insert.textToInsert, 'bold');
      expect(insert.attributions, contains(boldAttribution));
    });
  });
}

/// Records every `execute(...)` call without forwarding to a real
/// pipeline. Lets us assert on the requests the reaction emits without
/// pulling in super_editor's full command-handler graph.
class _RecordingDispatcher implements RequestDispatcher {
  final List<List<EditRequest>> executedRequests = [];

  @override
  void execute(List<EditRequest> requests) {
    executedRequests.add(List.unmodifiable(requests));
  }
}
