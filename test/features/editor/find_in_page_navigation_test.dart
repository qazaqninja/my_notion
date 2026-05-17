import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/document_search.dart';
import 'package:my_notion/features/editor/domain/find_in_page_navigation.dart';
import 'package:super_editor/super_editor.dart';

const _m0 = DocumentMatch(nodeId: 'n0', start: 0, end: 5);
const _m1 = DocumentMatch(nodeId: 'n1', start: 3, end: 7);
const _m2 = DocumentMatch(nodeId: 'n2', start: 10, end: 14);

void main() {
  group('selectionRequestForMatch', () {
    test('builds an expandSelection request spanning the match', () {
      final req = selectionRequestForMatch(_m0);
      expect(req.changeType, SelectionChangeType.expandSelection);
      expect(req.reason, 'find-in-page');
      final sel = req.newSelection!;
      expect(sel.base.nodeId, 'n0');
      expect((sel.base.nodePosition as TextNodePosition).offset, 0);
      expect(sel.extent.nodeId, 'n0');
      expect((sel.extent.nodePosition as TextNodePosition).offset, 5);
    });
  });

  group('MatchCursor', () {
    group('empty / construction', () {
      test('empty cursor reports isEmpty + null current', () {
        final c = MatchCursor.empty();
        expect(c.isEmpty, isTrue);
        expect(c.count, 0);
        expect(c.current, isNull);
        expect(c.index, -1);
      });

      test('initial on empty list yields empty cursor', () {
        final c = MatchCursor.initial(const []);
        expect(c.isEmpty, isTrue);
        expect(c.index, -1);
      });

      test('initial on non-empty list starts at index 0', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]);
        expect(c.count, 3);
        expect(c.index, 0);
        expect(c.current, _m0);
      });
    });

    group('next', () {
      test('advances to the next index', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]);
        expect(c.next().index, 1);
        expect(c.next().current, _m1);
      });

      test('wraps from last back to first', () {
        var c = MatchCursor.initial(const [_m0, _m1, _m2]);
        c = c.next().next(); // index 2
        expect(c.current, _m2);
        c = c.next();
        expect(c.index, 0);
        expect(c.current, _m0);
      });

      test('no-op on empty cursor', () {
        final c = MatchCursor.empty();
        expect(c.next(), c);
      });
    });

    group('previous', () {
      test('moves to the previous index', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]).next(); // 1
        expect(c.previous().index, 0);
      });

      test('wraps from first back to last', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]);
        final p = c.previous();
        expect(p.index, 2);
        expect(p.current, _m2);
      });

      test('no-op on empty cursor', () {
        final c = MatchCursor.empty();
        expect(c.previous(), c);
      });
    });

    group('goTo', () {
      test('jumps to a valid index', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]);
        expect(c.goTo(2).index, 2);
        expect(c.goTo(2).current, _m2);
      });

      test('returns self on out-of-bounds index', () {
        final c = MatchCursor.initial(const [_m0, _m1, _m2]);
        expect(c.goTo(-1), c);
        expect(c.goTo(3), c);
      });

      test('no-op on empty cursor', () {
        final c = MatchCursor.empty();
        expect(c.goTo(0), c);
      });
    });

    group('equality', () {
      test('MatchCursor equality is value-based', () {
        final a = MatchCursor.initial(const [_m0, _m1]);
        final b = MatchCursor.initial(const [_m0, _m1]);
        final c = MatchCursor.initial(const [_m0, _m1]).next();
        expect(a, b);
        expect(a, isNot(c));
      });
    });
  });
}
