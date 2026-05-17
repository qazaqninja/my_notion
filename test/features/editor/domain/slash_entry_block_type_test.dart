import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/slash_entry_block_type.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('blockTypeForLinePrefix', () {
    test('"# " → header1Attribution', () {
      expect(blockTypeForLinePrefix('# '), header1Attribution);
    });

    test('"## " → header2Attribution', () {
      expect(blockTypeForLinePrefix('## '), header2Attribution);
    });

    test('"### " → header3Attribution', () {
      expect(blockTypeForLinePrefix('### '), header3Attribution);
    });

    test('"> " → blockquoteAttribution', () {
      expect(blockTypeForLinePrefix('> '), blockquoteAttribution);
    });

    test('list / todo prefixes return null (handled by sibling mappers)', () {
      expect(blockTypeForLinePrefix('- '), isNull);
      expect(blockTypeForLinePrefix('1. '), isNull);
      expect(blockTypeForLinePrefix('- [ ] '), isNull);
    });

    test('empty / whitespace / arbitrary strings return null', () {
      expect(blockTypeForLinePrefix(''), isNull);
      expect(blockTypeForLinePrefix(' '), isNull);
      expect(blockTypeForLinePrefix('# foo'), isNull);
    });
  });

  group('listItemTypeForLinePrefix', () {
    test('"- " → ListItemType.unordered', () {
      expect(listItemTypeForLinePrefix('- '), ListItemType.unordered);
    });

    test('"1. " → ListItemType.ordered', () {
      expect(listItemTypeForLinePrefix('1. '), ListItemType.ordered);
    });

    test('todo / heading / blockquote prefixes return null', () {
      expect(listItemTypeForLinePrefix('- [ ] '), isNull);
      expect(listItemTypeForLinePrefix('# '), isNull);
      expect(listItemTypeForLinePrefix('> '), isNull);
    });

    test('empty / arbitrary strings return null', () {
      expect(listItemTypeForLinePrefix(''), isNull);
      expect(listItemTypeForLinePrefix('- a'), isNull);
    });
  });

  group('isTaskLinePrefix', () {
    test('"- [ ] " → true', () {
      expect(isTaskLinePrefix('- [ ] '), isTrue);
    });

    test('list / heading prefixes → false', () {
      expect(isTaskLinePrefix('- '), isFalse);
      expect(isTaskLinePrefix('1. '), isFalse);
      expect(isTaskLinePrefix('# '), isFalse);
    });

    test('checked-todo variant "- [x] " is NOT matched — slash menu only '
        'emits the empty-checkbox variant; pre-checked is a v1.x ask', () {
      expect(isTaskLinePrefix('- [x] '), isFalse);
    });

    test('empty / arbitrary strings → false', () {
      expect(isTaskLinePrefix(''), isFalse);
      expect(isTaskLinePrefix('- [ ]'), isFalse); // missing trailing space
    });
  });
}
