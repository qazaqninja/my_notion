import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/find_in_page_controller.dart';

void main() {
  // open() schedules a post-frame focus + select-all via
  // WidgetsBinding.instance, so the test binding must be initialised
  // before the first test runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FindInPageController (H3a)', () {
    late ScrollController scroll;
    late FindInPageController ctl;

    setUp(() {
      // Unattached ScrollController — hasClients is false in tests so the
      // controller's scroll-to-match path no-ops without throwing.
      scroll = ScrollController();
      ctl = FindInPageController(scroll: scroll);
      addTearDown(() {
        ctl.dispose();
        scroll.dispose();
      });
    });

    group('open() / close()', () {
      test('starts closed', () {
        expect(ctl.isOpen, isFalse);
      });

      test('open() flips isOpen + notifies', () {
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.open();
        expect(ctl.isOpen, isTrue);
        expect(fires, 1);
      });

      test('second open() while already open is a no-op (no notify)', () {
        ctl.open();
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.open();
        expect(fires, 0);
      });

      test('close() clears matches + cursor + isOpen + notifies', () {
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo bar\nfoo baz');
        expect(ctl.matches, isNotEmpty);
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.close();
        expect(ctl.isOpen, isFalse);
        expect(ctl.matches, isEmpty);
        expect(ctl.cursor, 0);
        expect(fires, 1);
      });
    });

    group('recompute()', () {
      setUp(() {
        // recompute() is open-state-agnostic in this implementation,
        // but callers always recompute through an open find bar — keep
        // tests faithful to the real call sequence.
        ctl.open();
      });

      test('empty query clears matches', () {
        ctl.queryController.text = '';
        ctl.recompute('one\ntwo\nthree');
        expect(ctl.matches, isEmpty);
      });

      test('records one line index per matched line', () {
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo again\nbaz\nfoo');
        // matches on lines 0, 2, 4
        expect(ctl.matches, [0, 2, 4]);
        expect(ctl.cursor, 0);
      });

      test('case-insensitive matching', () {
        ctl.queryController.text = 'FOO';
        ctl.recompute('foo\nFoo\nFOO');
        expect(ctl.matches, [0, 1, 2]);
      });

      test('multiple hits on the same line only count once', () {
        ctl.queryController.text = 'foo';
        ctl.recompute('foo foo foo\nbar');
        // Line 0 has 3 hits but only counts once.
        expect(ctl.matches, [0]);
      });

      test('no matches → matches empty, cursor 0', () {
        ctl.queryController.text = 'qux';
        ctl.recompute('foo\nbar');
        expect(ctl.matches, isEmpty);
        expect(ctl.cursor, 0);
      });

      test('trims surrounding whitespace from query', () {
        ctl.queryController.text = '   foo   ';
        ctl.recompute('foo\nbar');
        expect(ctl.matches, [0]);
      });
    });

    group('step()', () {
      test('is a no-op when no matches', () {
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.step(1, 'foo\nbar');
        expect(fires, 0);
      });

      test('forward step advances cursor', () {
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo\nbaz\nfoo');
        // matches = [0, 2, 4]; cursor starts at 0
        ctl.step(1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 1);
        ctl.step(1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 2);
      });

      test('forward step wraps around past the last match', () {
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo');
        // matches = [0, 2]; cursor = 0
        ctl.step(1, 'foo\nbar\nfoo');
        expect(ctl.cursor, 1);
        ctl.step(1, 'foo\nbar\nfoo');
        expect(ctl.cursor, 0);
      });

      test('backward step from 0 wraps to last', () {
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo\nbaz\nfoo');
        // matches = [0, 2, 4]; cursor = 0
        ctl.step(-1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 2);
      });
    });
  });
}
