import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/crdt/domain/entities/quill_crdt_doc.dart';
import 'package:my_notion/features/crdt/domain/usecases/markdown_crdt_serializer.dart';

/// H1 — proof-of-concept tests for the CRDT seam. Future slices
/// (H2+) swap the implementation for y_crdt; these contracts
/// stay green throughout because they exercise the public
/// `QuillCrdtDoc` surface, not the storage shape.
void main() {
  group('QuillCrdtDoc (H1)', () {
    const sample = '''
# Test page

A first line.
A second line.
''';

    test('empty() yields body == "" and clock 0', () {
      final doc = QuillCrdtDoc.empty();
      expect(doc.body, '');
      expect(doc.clock, 0);
    });

    test('fromMarkdown round-trips through toMarkdown byte-identically',
        () {
      const ser = MarkdownCrdtSerializer();
      final doc = ser.fromMarkdown(sample);
      expect(ser.toMarkdown(doc), sample);
    });

    test('fromMarkdown seeds clock with the line count', () {
      final doc = QuillCrdtDoc.fromMarkdown(sample);
      // sample has 5 newline-separated segments (including the
      // trailing empty one after the final newline).
      expect(doc.clock, 5);
    });

    test('apply(SetBody) returns a new doc with body replaced + clock++',
        () {
      final doc = QuillCrdtDoc.fromMarkdown(sample);
      final next = doc.apply(const QuillCrdtSetBody('# Rewritten\n'));
      expect(next.body, '# Rewritten\n');
      expect(next.clock, doc.clock + 1);
      // Immutability — the original is untouched.
      expect(doc.body, sample);
    });

    test('Equality compares body + clock', () {
      final a = QuillCrdtDoc.fromMarkdown(sample);
      final b = QuillCrdtDoc.fromMarkdown(sample);
      expect(a, equals(b));
      final aPlus = a.apply(const QuillCrdtSetBody('x'));
      expect(a, isNot(equals(aPlus)));
    });

    test('Empty markdown produces clock=0 doc', () {
      final doc = QuillCrdtDoc.fromMarkdown('');
      expect(doc.body, '');
      expect(doc.clock, 0);
    });

    test('Single-line markdown without trailing newline preserves shape',
        () {
      const oneLiner = 'just one line';
      const ser = MarkdownCrdtSerializer();
      final doc = ser.fromMarkdown(oneLiner);
      expect(ser.toMarkdown(doc), oneLiner);
      expect(doc.clock, 1);
    });
  });
}
