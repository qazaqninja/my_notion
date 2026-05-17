import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_selection.dart';

void main() {
  group('BlockSelection', () {
    group('empty factory', () {
      test('empty() reports isEmpty / isNotEmpty / size 0', () {
        final s = BlockSelection.empty();
        expect(s.isEmpty, isTrue);
        expect(s.isNotEmpty, isFalse);
        expect(s.size, 0);
        expect(s.nodeIds, isEmpty);
      });

      test('empty().isSelected returns false for any id', () {
        expect(BlockSelection.empty().isSelected('a'), isFalse);
      });
    });

    group('add', () {
      test('add to empty includes the id', () {
        final s = BlockSelection.empty().add('a');
        expect(s.size, 1);
        expect(s.isSelected('a'), isTrue);
      });

      test('add returns a new instance (immutable)', () {
        final s1 = BlockSelection.empty();
        final s2 = s1.add('a');
        expect(s1.isEmpty, isTrue);
        expect(s2.size, 1);
      });

      test('add an already-selected id is idempotent', () {
        final s = BlockSelection.empty().add('a').add('a');
        expect(s.size, 1);
      });
    });

    group('remove', () {
      test('remove an unselected id is a no-op', () {
        final s = BlockSelection.empty().remove('a');
        expect(s.isEmpty, isTrue);
      });

      test('remove a selected id drops it from the set', () {
        final s = BlockSelection.empty().add('a').add('b').remove('a');
        expect(s.isSelected('a'), isFalse);
        expect(s.isSelected('b'), isTrue);
        expect(s.size, 1);
      });
    });

    group('toggle', () {
      test('toggle adds when missing', () {
        final s = BlockSelection.empty().toggle('a');
        expect(s.isSelected('a'), isTrue);
      });

      test('toggle removes when present', () {
        final s = BlockSelection.empty().add('a').toggle('a');
        expect(s.isSelected('a'), isFalse);
      });
    });

    group('clear / replaceWith', () {
      test('clear() empties the set', () {
        final s = BlockSelection.empty().add('a').add('b').clear();
        expect(s.isEmpty, isTrue);
      });

      test('replaceWith replaces the set', () {
        final s = BlockSelection.empty().add('x').replaceWith({'a', 'b'});
        expect(s.size, 2);
        expect(s.isSelected('a'), isTrue);
        expect(s.isSelected('b'), isTrue);
        expect(s.isSelected('x'), isFalse);
      });

      test('replaceWith copies the input — caller mutation is safe', () {
        final input = <String>{'a', 'b'};
        final s = BlockSelection.empty().replaceWith(input);
        input.add('c');
        expect(s.size, 2);
        expect(s.isSelected('c'), isFalse);
      });
    });

    group('value equality', () {
      test('two selections with same node ids are ==', () {
        final s1 = BlockSelection.empty().add('a').add('b');
        final s2 = BlockSelection.empty().add('b').add('a');
        expect(s1, equals(s2));
        expect(s1.hashCode, equals(s2.hashCode));
      });

      test('different node ids are not equal', () {
        final s1 = BlockSelection.empty().add('a');
        final s2 = BlockSelection.empty().add('b');
        expect(s1, isNot(equals(s2)));
      });

      test('empty selections are equal', () {
        expect(BlockSelection.empty(), equals(BlockSelection.empty()));
      });
    });
  });
}
