import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_conversion.dart';
import 'package:my_notion/features/editor/presentation/controllers/block_conversion_keyboard_action.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('parseBlockConversionKey', () {
    const digit7Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit7,
      logicalKey: LogicalKeyboardKey.digit7,
      timeStamp: Duration.zero,
    );
    const digit8Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit8,
      logicalKey: LogicalKeyboardKey.digit8,
      timeStamp: Duration.zero,
    );
    const digit9Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit9,
      logicalKey: LogicalKeyboardKey.digit9,
      timeStamp: Duration.zero,
    );
    const digit7Up = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.digit7,
      logicalKey: LogicalKeyboardKey.digit7,
      timeStamp: Duration.zero,
    );
    const digit5Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit5,
      logicalKey: LogicalKeyboardKey.digit5,
      timeStamp: Duration.zero,
    );

    group('happy path', () {
      test('Cmd+Shift+7 returns orderedList', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit7Down,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockConversion.orderedList,
        );
      });

      test('Cmd+Shift+8 returns unorderedList', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit8Down,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockConversion.unorderedList,
        );
      });

      test('Cmd+Shift+9 returns task', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit9Down,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockConversion.task,
        );
      });
    });

    group('no match', () {
      test('KeyUpEvent — only Down/Repeat trigger', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit7Up,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('shift not pressed — does not trigger', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit7Down,
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('primary shortcut not pressed — does not trigger', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit7Down,
            isShiftPressed: true,
            isPrimaryShortcutPressed: false,
          ),
          isNull,
        );
      });

      test('non-matching digit (Cmd+Shift+5) does not trigger', () {
        expect(
          parseBlockConversionKey(
            keyEvent: digit5Down,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });
    });
  });

  group('requestsForBlockConversion', () {
    group('paragraph source', () {
      test('to unordered list returns single ConvertParagraphToListItem', () {
        final source = ParagraphNode(id: 'p1', text: AttributedText('x'));
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.unorderedList,
        );
        expect(requests, hasLength(1));
        expect(requests!.first, isA<ConvertParagraphToListItemRequest>());
        final r = requests.first as ConvertParagraphToListItemRequest;
        expect(r.nodeId, 'p1');
        expect(r.type, ListItemType.unordered);
      });

      test('to ordered list emits ListItemType.ordered', () {
        final source = ParagraphNode(id: 'p1', text: AttributedText('x'));
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.orderedList,
        );
        final r = requests!.first as ConvertParagraphToListItemRequest;
        expect(r.type, ListItemType.ordered);
      });

      test('to task returns single ConvertParagraphToTask', () {
        final source = ParagraphNode(id: 'p1', text: AttributedText('x'));
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.task,
        );
        expect(requests, hasLength(1));
        expect(requests!.first, isA<ConvertParagraphToTaskRequest>());
      });
    });

    group('list-item source', () {
      test('same list type returns null (no-op)', () {
        final source = ListItemNode(
          id: 'l1',
          itemType: ListItemType.unordered,
          text: AttributedText('x'),
        );
        expect(
          requestsForBlockConversion(
            source: source,
            target: BlockConversion.unorderedList,
          ),
          isNull,
        );
      });

      test('switching list type chains through paragraph', () {
        final source = ListItemNode(
          id: 'l1',
          itemType: ListItemType.unordered,
          text: AttributedText('x'),
        );
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.orderedList,
        );
        expect(requests, hasLength(2));
        expect(requests![0], isA<ConvertListItemToParagraphRequest>());
        expect(requests[1], isA<ConvertParagraphToListItemRequest>());
        expect(
          (requests[1] as ConvertParagraphToListItemRequest).type,
          ListItemType.ordered,
        );
      });

      test('to task chains list→paragraph→task', () {
        final source = ListItemNode(
          id: 'l1',
          itemType: ListItemType.unordered,
          text: AttributedText('x'),
        );
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.task,
        );
        expect(requests, hasLength(2));
        expect(requests![0], isA<ConvertListItemToParagraphRequest>());
        expect(requests[1], isA<ConvertParagraphToTaskRequest>());
      });
    });

    group('task source', () {
      test('to task returns null (no-op)', () {
        final source = TaskNode(
          id: 't1',
          text: AttributedText('x'),
          isComplete: false,
        );
        expect(
          requestsForBlockConversion(
            source: source,
            target: BlockConversion.task,
          ),
          isNull,
        );
      });

      test('to ordered list chains task→paragraph→list', () {
        final source = TaskNode(
          id: 't1',
          text: AttributedText('x'),
          isComplete: false,
        );
        final requests = requestsForBlockConversion(
          source: source,
          target: BlockConversion.orderedList,
        );
        expect(requests, hasLength(2));
        expect(requests![0], isA<ConvertTaskToParagraphRequest>());
        expect(requests[1], isA<ConvertParagraphToListItemRequest>());
        expect(
          (requests[1] as ConvertParagraphToListItemRequest).type,
          ListItemType.ordered,
        );
      });
    });

    group('non-text source', () {
      test('HorizontalRuleNode returns null', () {
        final source = HorizontalRuleNode(id: 'hr');
        expect(
          requestsForBlockConversion(
            source: source,
            target: BlockConversion.task,
          ),
          isNull,
        );
      });
    });
  });
}
