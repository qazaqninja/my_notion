import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/block_id.dart';

void main() {
  const ulid = '01HZBLOCKAAAAAAAAAAAAAAAAA';

  group('BlockId.split', () {
    test('extracts trailing ^<ULID> and strips it from text', () {
      final (text, id) = BlockId.split('a paragraph here ^$ulid');
      expect(text, 'a paragraph here');
      expect(id, ulid);
    });

    test('no suffix → text unchanged, id null', () {
      final (text, id) = BlockId.split('plain paragraph');
      expect(text, 'plain paragraph');
      expect(id, isNull);
    });

    test('caret without 26-char ULID is not consumed', () {
      final (text, id) = BlockId.split('caret ^notanid');
      expect(text, 'caret ^notanid');
      expect(id, isNull);
    });

    test('lowercase ULID is rejected (we require uppercase Crockford)', () {
      final lower = ulid.toLowerCase();
      final (text, id) = BlockId.split('p ^$lower');
      expect(text, 'p ^$lower');
      expect(id, isNull);
    });

    test('preserves leading content with internal carets', () {
      final (text, id) = BlockId.split('a ^foo and b ^$ulid');
      expect(text, 'a ^foo and b');
      expect(id, ulid);
    });

    test('trailing whitespace after the id is tolerated', () {
      final (text, id) = BlockId.split('p ^$ulid  ');
      expect(text, 'p');
      expect(id, ulid);
    });
  });

  group('BlockId.append', () {
    test('appends to a clean line', () {
      expect(BlockId.append('hello', ulid), 'hello ^$ulid');
    });

    test('replaces an existing id', () {
      const newId = '01HZBLOCKBBBBBBBBBBBBBBBBB';
      expect(BlockId.append('hello ^$ulid', newId), 'hello ^$newId');
    });
  });
}
