import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/insert_link.dart';

void main() {
  group('findMarkdownLinkAt', () {
    test('returns the surrounding link when caret is on the label', () {
      const text = 'see [docs](https://example.com) for more';
      final hit = findMarkdownLinkAt(text, 7); // inside "docs"
      expect(hit, isNotNull);
      expect(hit!.label, 'docs');
      expect(hit.url, 'https://example.com');
      expect(text.substring(hit.start, hit.end), '[docs](https://example.com)');
    });

    test('returns the link when caret is at the leading [', () {
      const text = '[docs](https://example.com)';
      final hit = findMarkdownLinkAt(text, 0);
      expect(hit, isNotNull);
      expect(hit!.url, 'https://example.com');
    });

    test('returns the link when caret is at the trailing )', () {
      const text = '[docs](https://example.com)';
      final hit = findMarkdownLinkAt(text, text.length);
      expect(hit, isNotNull);
      expect(hit!.label, 'docs');
    });

    test('returns null when the caret is outside any link', () {
      expect(findMarkdownLinkAt('plain text here', 5), isNull);
    });

    test('returns null when label spans a newline', () {
      const text = '[part one\nbroken](url)';
      expect(findMarkdownLinkAt(text, 4), isNull);
    });

    test('returns null when the URL contains whitespace', () {
      const text = '[label](not a url)';
      expect(findMarkdownLinkAt(text, 3), isNull);
    });

    test('returns null when the URL contains a newline', () {
      const text = '[label](url\nbroken)';
      expect(findMarkdownLinkAt(text, 3), isNull);
    });

    test('only the link the caret straddles is returned', () {
      const text = '[a](x) and [b](y)';
      final first = findMarkdownLinkAt(text, 2);
      expect(first!.url, 'x');
      final second = findMarkdownLinkAt(text, 13);
      expect(second!.url, 'y');
    });

    test('returns null when caret is between two links but outside both', () {
      const text = '[a](x) and [b](y)';
      // Position 6 = the space after `)`; caret 7 is "a" in "and".
      expect(findMarkdownLinkAt(text, 8), isNull);
    });

    test('rejects malformed link without closing paren', () {
      const text = '[label](http://example.com';
      expect(findMarkdownLinkAt(text, 5), isNull);
    });
  });
}
