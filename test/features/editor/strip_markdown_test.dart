import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/strip_markdown.dart';

void main() {
  group('stripMarkdown', () {
    test('strips heading hashes', () {
      expect(stripMarkdown('# Title'), 'Title');
      expect(stripMarkdown('## Sub'), 'Sub');
    });

    test('keeps bullet text without the marker', () {
      expect(stripMarkdown('- one\n- two'), 'one\ntwo');
    });

    test('strips checkbox markers', () {
      expect(
        stripMarkdown('- [ ] todo\n- [x] done'),
        'todo\ndone',
      );
    });

    test('strips inline emphasis but keeps content', () {
      expect(
        stripMarkdown('this is **bold** and *italic* and ~~struck~~'),
        'this is bold and italic and struck',
      );
    });

    test('strips inline code backticks', () {
      expect(stripMarkdown('use `flutter test`'), 'use flutter test');
    });

    test('drops fenced code blocks entirely', () {
      const src = 'before\n```\ncode line\n```\nafter';
      expect(stripMarkdown(src), 'before\nafter');
    });

    test('keeps link label + URL', () {
      expect(
        stripMarkdown('See [Quill](https://example.com).'),
        'See Quill (https://example.com).',
      );
    });

    test('drops `[[ULID]]` wikilinks (meaningless out of context)', () {
      expect(
        stripMarkdown('Linked: [[01HX0V9R5N6E8L3P7Q8S9U2X4B]]'),
        'Linked:',
      );
    });

    test('image link collapses to alt text', () {
      expect(
        stripMarkdown('![cover](assets/cover.png)'),
        'cover',
      );
    });

    test('strips highlight ==…== markers', () {
      expect(stripMarkdown('I want to ==highlight=='), 'I want to highlight');
    });

    test('strips blockquote markers', () {
      expect(stripMarkdown('> quoted text'), 'quoted text');
    });
  });
}
