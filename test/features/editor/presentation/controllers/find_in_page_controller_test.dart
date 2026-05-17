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

    setUp(() {
      // Unattached ScrollController — hasClients is false in tests so the
      // controller's scroll-to-match path no-ops without throwing.
      scroll = ScrollController();
    });

    tearDown(() {
      scroll.dispose();
    });

    group('open() / close()', () {
      test('starts closed', () {
        final ctl = FindInPageController(scroll: scroll);
        expect(ctl.isOpen, isFalse);
        ctl.dispose();
      });

      test('open() flips isOpen + notifies', () {
        final ctl = FindInPageController(scroll: scroll);
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.open();
        expect(ctl.isOpen, isTrue);
        expect(fires, 1);
        ctl.dispose();
      });

      test('second open() while already open is a no-op (no notify)', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.open();
        expect(fires, 0);
        ctl.dispose();
      });

      test('close() clears matches + cursor + isOpen + notifies', () {
        final ctl = FindInPageController(scroll: scroll);
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
        ctl.dispose();
      });
    });

    group('recompute()', () {
      test('empty query clears matches', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = '';
        ctl.recompute('one\ntwo\nthree');
        expect(ctl.matches, isEmpty);
        ctl.dispose();
      });

      test('records one line index per matched line', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo again\nbaz\nfoo');
        // matches on lines 0, 2, 4
        expect(ctl.matches, [0, 2, 4]);
        expect(ctl.cursor, 0);
        ctl.dispose();
      });

      test('case-insensitive matching', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'FOO';
        ctl.recompute('foo\nFoo\nFOO');
        expect(ctl.matches, [0, 1, 2]);
        ctl.dispose();
      });

      test('multiple hits on the same line only count once', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo foo foo\nbar');
        // Line 0 has 3 hits but only counts once.
        expect(ctl.matches, [0]);
        ctl.dispose();
      });

      test('no matches → matches empty, cursor 0', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'qux';
        ctl.recompute('foo\nbar');
        expect(ctl.matches, isEmpty);
        expect(ctl.cursor, 0);
        ctl.dispose();
      });

      test('trims surrounding whitespace from query', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = '   foo   ';
        ctl.recompute('foo\nbar');
        expect(ctl.matches, [0]);
        ctl.dispose();
      });
    });

    group('step()', () {
      test('is a no-op when no matches', () {
        final ctl = FindInPageController(scroll: scroll);
        var fires = 0;
        ctl.addListener(() => fires++);
        ctl.step(1, 'foo\nbar');
        expect(fires, 0);
        ctl.dispose();
      });

      test('forward step advances cursor', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo\nbaz\nfoo');
        // matches = [0, 2, 4]; cursor starts at 0
        ctl.step(1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 1);
        ctl.step(1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 2);
        ctl.dispose();
      });

      test('forward step wraps around past the last match', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo');
        // matches = [0, 2]; cursor = 0
        ctl.step(1, 'foo\nbar\nfoo');
        expect(ctl.cursor, 1);
        ctl.step(1, 'foo\nbar\nfoo');
        expect(ctl.cursor, 0);
        ctl.dispose();
      });

      test('backward step from 0 wraps to last', () {
        final ctl = FindInPageController(scroll: scroll);
        ctl.open();
        ctl.queryController.text = 'foo';
        ctl.recompute('foo\nbar\nfoo\nbaz\nfoo');
        // matches = [0, 2, 4]; cursor = 0
        ctl.step(-1, 'foo\nbar\nfoo\nbaz\nfoo');
        expect(ctl.cursor, 2);
        ctl.dispose();
      });
    });
  });
}
