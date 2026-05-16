import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/text_cleanup_ops.dart';

/// Smoke-tests for the cleanup ops re-exported from
/// `source_line_ops.dart`. The full behavior matrix for each
/// function lives in `test/features/editor/selection_line_ops_test.dart`
/// where they share fixtures with the broader source_line_ops
/// family — this file exists to mirror the lib-tree shape per
/// the testing convention (FS-04 / TS-01) so each top-level
/// file in `lib/features/editor/domain/` has a `_test.dart`
/// sibling for discoverability.
void main() {
  group('removeAccentsLinesIn (smoke)', () {
    test('plain ASCII passes through unchanged', () {
      const text = 'plain text\n';
      expect(removeAccentsLinesIn(text, 0, text.length).text, 'plain text\n');
    });

    test('folds Latin diacritics to base letters', () {
      const text = 'café résumé\n';
      expect(
        removeAccentsLinesIn(text, 0, text.length).text,
        'cafe resume\n',
      );
    });

    test('empty input stays empty', () {
      expect(removeAccentsLinesIn('', 0, 0).text, '');
    });
  });

  group('removeUrlsLinesIn (smoke)', () {
    test('drops bare URLs from prose', () {
      const text = 'see https://x.test for context\n';
      expect(
        removeUrlsLinesIn(text, 0, text.length).text,
        'see  for context\n',
      );
    });

    test('plain prose passes through unchanged', () {
      const text = 'plain text\n';
      expect(removeUrlsLinesIn(text, 0, text.length).text, 'plain text\n');
    });

    test('empty input stays empty', () {
      expect(removeUrlsLinesIn('', 0, 0).text, '');
    });
  });

  group('escapeMarkdownLinesIn (smoke)', () {
    test('escapes bold delimiters', () {
      const text = '**bold**\n';
      expect(
        escapeMarkdownLinesIn(text, 0, text.length).text,
        r'\*\*bold\*\*' '\n',
      );
    });

    test('empty input stays empty', () {
      expect(escapeMarkdownLinesIn('', 0, 0).text, '');
    });
  });

  group('stripEmojiLinesIn (smoke)', () {
    test('drops emoji from prose', () {
      const text = 'hello 👋 world\n';
      expect(
        stripEmojiLinesIn(text, 0, text.length).text,
        'hello  world\n',
      );
    });

    test('plain ASCII passes through unchanged', () {
      const text = 'plain text\n';
      expect(stripEmojiLinesIn(text, 0, text.length).text, 'plain text\n');
    });

    test('empty input stays empty', () {
      expect(stripEmojiLinesIn('', 0, 0).text, '');
    });
  });

  group('stripMarkdownEmphasisLinesIn (smoke)', () {
    test('unwraps bold and italic delimiters', () {
      const text = '**bold** and *italic*\n';
      expect(
        stripMarkdownEmphasisLinesIn(text, 0, text.length).text,
        'bold and italic\n',
      );
    });

    test('empty input stays empty', () {
      expect(stripMarkdownEmphasisLinesIn('', 0, 0).text, '');
    });
  });

  group('stripLeadingNumberPrefixIn (smoke)', () {
    test('strips `1. ` from list lines', () {
      const text = '1. first\n2. second\n';
      expect(
        stripLeadingNumberPrefixIn(text, 0, text.length).text,
        'first\nsecond\n',
      );
    });

    test('plain lines pass through unchanged', () {
      const text = 'plain text\n';
      expect(
        stripLeadingNumberPrefixIn(text, 0, text.length).text,
        'plain text\n',
      );
    });

    test('empty input stays empty', () {
      expect(stripLeadingNumberPrefixIn('', 0, 0).text, '');
    });
  });

  group('stripHtmlTagsLinesIn (smoke)', () {
    test('drops `<tag>` markers, keeps content', () {
      const text = '<p>hello</p>\n';
      expect(
        stripHtmlTagsLinesIn(text, 0, text.length).text,
        'hello\n',
      );
    });

    test('plain prose passes through unchanged', () {
      const text = 'plain text\n';
      expect(stripHtmlTagsLinesIn(text, 0, text.length).text, 'plain text\n');
    });

    test('empty input stays empty', () {
      expect(stripHtmlTagsLinesIn('', 0, 0).text, '');
    });
  });

  group('stripMarkdownLinksLinesIn (smoke)', () {
    test('unwraps `[label](url)` to keep just the label', () {
      const text = 'see [docs](https://x.test) now\n';
      expect(
        stripMarkdownLinksLinesIn(text, 0, text.length).text,
        'see docs now\n',
      );
    });

    test('plain prose passes through unchanged', () {
      const text = 'plain text\n';
      expect(
        stripMarkdownLinksLinesIn(text, 0, text.length).text,
        'plain text\n',
      );
    });

    test('empty input stays empty', () {
      expect(stripMarkdownLinksLinesIn('', 0, 0).text, '');
    });
  });
}
