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

    test('unknown prefix returns null', () {
      // List items + todos need a node-type change (ParagraphNode →
      // ListItemNode / TaskNode); they cannot be expressed via a
      // simple blockType metadata swap. Returning null lets the
      // caller fall back to a deferred no-op until slice 2g-d.
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
}
