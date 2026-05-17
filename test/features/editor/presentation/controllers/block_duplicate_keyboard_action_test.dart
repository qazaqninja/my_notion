import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/block_duplicate_keyboard_action.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('parseBlockDuplicateKey', () {
    const keyDDown = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyD,
      logicalKey: LogicalKeyboardKey.keyD,
      timeStamp: Duration.zero,
    );
    const keyDRepeat = KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.keyD,
      logicalKey: LogicalKeyboardKey.keyD,
      timeStamp: Duration.zero,
    );
    const keyDUp = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.keyD,
      logicalKey: LogicalKeyboardKey.keyD,
      timeStamp: Duration.zero,
    );
    const keyA = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );

    group('happy path', () {
      test('Cmd+D returns true', () {
        expect(
          parseBlockDuplicateKey(
            keyEvent: keyDDown,
            isPrimaryShortcutPressed: true,
          ),
          isTrue,
        );
      });

      test('Cmd+D KeyRepeatEvent also returns true', () {
        expect(
          parseBlockDuplicateKey(
            keyEvent: keyDRepeat,
            isPrimaryShortcutPressed: true,
          ),
          isTrue,
        );
      });
    });

    group('no match', () {
      test('KeyUpEvent — only Down/Repeat trigger', () {
        expect(
          parseBlockDuplicateKey(
            keyEvent: keyDUp,
            isPrimaryShortcutPressed: true,
          ),
          isFalse,
        );
      });

      test('Cmd not pressed', () {
        expect(
          parseBlockDuplicateKey(
            keyEvent: keyDDown,
            isPrimaryShortcutPressed: false,
          ),
          isFalse,
        );
      });

      test('non-D key (Cmd+A) does not trigger', () {
        expect(
          parseBlockDuplicateKey(
            keyEvent: keyA,
            isPrimaryShortcutPressed: true,
          ),
          isFalse,
        );
      });
    });
  });

  group('cloneBlockWithFreshId', () {
    test('clones ParagraphNode with fresh id, preserves text', () {
      final source = ParagraphNode(
        id: 'p1',
        text: AttributedText('hello world'),
      );
      final clone = cloneBlockWithFreshId(source);
      expect(clone, isA<ParagraphNode>());
      expect(clone!.id, isNot('p1'));
      expect((clone as ParagraphNode).text.toPlainText(), 'hello world');
    });

    test('clones ListItemNode preserving item type', () {
      final source = ListItemNode(
        id: 'l1',
        itemType: ListItemType.unordered,
        text: AttributedText('item'),
      );
      final clone = cloneBlockWithFreshId(source);
      expect(clone, isA<ListItemNode>());
      expect(clone!.id, isNot('l1'));
      expect((clone as ListItemNode).type, ListItemType.unordered);
    });

    test('clones TaskNode preserving isComplete', () {
      final source = TaskNode(
        id: 't1',
        text: AttributedText('task'),
        isComplete: true,
      );
      final clone = cloneBlockWithFreshId(source);
      expect(clone, isA<TaskNode>());
      expect(clone!.id, isNot('t1'));
      expect((clone as TaskNode).isComplete, isTrue);
    });

    test('clones HorizontalRuleNode with fresh id', () {
      final source = HorizontalRuleNode(id: 'hr1');
      final clone = cloneBlockWithFreshId(source);
      expect(clone, isA<HorizontalRuleNode>());
      expect(clone!.id, isNot('hr1'));
    });

    test('clones ImageNode preserving url + alt text', () {
      final source = ImageNode(
        id: 'img1',
        imageUrl: 'https://example.com/x.png',
        altText: 'an example',
      );
      final clone = cloneBlockWithFreshId(source);
      expect(clone, isA<ImageNode>());
      expect(clone!.id, isNot('img1'));
      expect((clone as ImageNode).imageUrl, 'https://example.com/x.png');
      expect(clone.altText, 'an example');
    });
  });
}
