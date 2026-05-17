import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/slash_trigger_session.dart';

void main() {
  group('SlashTriggerSession', () {
    late SlashTriggerSession session;
    late _CallbackRecorder rec;

    setUp(() {
      session = SlashTriggerSession();
      rec = _CallbackRecorder();
    });

    group('update — open path', () {
    test('fires onOpen when `/` is typed at column 0', () {
      session.update(
        text: '/',
        caret: 1,
        onOpen: rec.open,
        onDismiss: rec.dismiss,
        onQuery: rec.query,
      );
      expect(rec.opens, [0]);
      expect(rec.dismisses, 0);
      expect(rec.queries, isEmpty);
    });

    test('fires onOpen when `/` is typed after a whitespace boundary', () {
      session.update(
        text: 'foo /',
        caret: 5,
        onOpen: rec.open,
        onDismiss: rec.dismiss,
        onQuery: rec.query,
      );
      expect(rec.opens, [4]);
    });

    test('does NOT fire onOpen mid-word (https://...)', () {
      session.update(
        text: 'https:/',
        caret: 7,
        onOpen: rec.open,
        onDismiss: rec.dismiss,
        onQuery: rec.query,
      );
      expect(rec.opens, isEmpty);
    });
    });

    group('update — query path', () {
    test('subsequent keystrokes emit onQuery with the typed substring', () {
      session
        ..update(
          text: '/',
          caret: 1,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..update(
          text: '/h',
          caret: 2,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..update(
          text: '/he',
          caret: 3,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        );
      expect(rec.opens, [0]); // open fires exactly once
      expect(rec.queries, ['h', 'he']);
      expect(rec.dismisses, 0);
    });

    });

    group('update — dismiss path', () {
    test('typing a space after the slash dismisses', () {
      session
        ..update(
          text: '/',
          caret: 1,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..update(
          text: '/ ',
          caret: 2,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        );
      expect(rec.dismisses, 1);
    });

    test('caret jumping before the trigger dismisses', () {
      // Simulate typing `/foo` keystroke by keystroke so the session opens
      // on the first `/`, then jump the caret to offset 0.
      session
        ..update(
          text: '/',
          caret: 1,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..update(
          text: '/foo',
          caret: 4,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..update(
          text: '/foo',
          caret: 0,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        );
      expect(rec.dismisses, 1);
    });

    });

    group('reset', () {
    test('reset() clears the trigger so the next `/` opens cleanly', () {
      // Open the first trigger, reset it externally, then type more text
      // ending with a `/` after a space — the new `/` should open.
      session
        ..update(
          text: '/',
          caret: 1,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        )
        ..reset()
        ..update(
          text: 'a /',
          caret: 3,
          onOpen: rec.open,
          onDismiss: rec.dismiss,
          onQuery: rec.query,
        );
      // First open at offset 0 (caret 1, '/' just before caret).
      // Second open at offset 2 (caret 3, '/' just before caret).
      expect(rec.opens, [0, 2]);
    });

    });

    group('idle update', () {
    test('non-selection / no-caret update fires neither open nor query', () {
      session.update(
        text: 'foo',
        caret: 2,
        onOpen: rec.open,
        onDismiss: rec.dismiss,
        onQuery: rec.query,
      );
      expect(rec.opens, isEmpty);
      expect(rec.queries, isEmpty);
      expect(rec.dismisses, 0);
    });
    });
  });
}

class _CallbackRecorder {
  final List<int> opens = <int>[];
  final List<String> queries = <String>[];
  int dismisses = 0;

  void open(int triggerOffset) => opens.add(triggerOffset);
  void query(String q) => queries.add(q);
  void dismiss() => dismisses += 1;
}
