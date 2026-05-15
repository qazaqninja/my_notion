import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/insert_link.dart';

void main() {
  group('insertMarkdownLink', () {
    test('inserts [label](url) at caret (zero-width selection)', () {
      final r = insertMarkdownLink(
        text: 'hello world',
        start: 5,
        end: 5,
        label: 'space',
        url: 'https://example.com',
      );
      expect(r.text, 'hello[space](https://example.com) world');
      expect(r.caret, 5 + '[space](https://example.com)'.length);
    });

    test('replaces selection with [label](url) when non-empty', () {
      final r = insertMarkdownLink(
        text: 'click here for details',
        start: 6,
        end: 10,
        label: 'here',
        url: 'https://docs.example.com',
      );
      expect(r.text, 'click [here](https://docs.example.com) for details');
      expect(r.caret, 6 + '[here](https://docs.example.com)'.length);
    });

    test('empty label and empty url survive — caller decides', () {
      final r = insertMarkdownLink(
        text: 'before after', start: 7, end: 7, label: '', url: '');
      expect(r.text, 'before []()after');
    });

    test('clamps out-of-range start / end into the text bounds', () {
      final r = insertMarkdownLink(
        text: 'hi', start: -3, end: 99, label: 'x', url: 'y');
      expect(r.text, '[x](y)');
    });

    test('URL with parentheses gets <angle-bracket> wrap (CommonMark)', () {
      final r = insertMarkdownLink(
        text: '',
        start: 0,
        end: 0,
        label: 'Apple',
        url: 'https://en.wikipedia.org/wiki/Apple_(disambiguation)',
      );
      expect(
        r.text,
        '[Apple](<https://en.wikipedia.org/wiki/Apple_(disambiguation)>)',
      );
    });

    test('label with ] gets backslash-escaped', () {
      final r = insertMarkdownLink(
        text: '',
        start: 0,
        end: 0,
        label: 'see [appendix]',
        url: 'https://example.com',
      );
      expect(r.text, r'[see [appendix\]](https://example.com)');
    });

    test('URL without parens is unwrapped (no <…>)', () {
      final r = insertMarkdownLink(
        text: '',
        start: 0,
        end: 0,
        label: 'x',
        url: 'https://example.com/path',
      );
      expect(r.text, '[x](https://example.com/path)');
    });
  });

  group('looksLikeUrl', () {
    test('accepts http and https schemes', () {
      expect(looksLikeUrl('http://example.com'), isTrue);
      expect(looksLikeUrl('https://example.com'), isTrue);
      expect(looksLikeUrl('HTTPS://EXAMPLE.COM'), isTrue);
    });

    test('accepts www. and mailto: and ftp://', () {
      expect(looksLikeUrl('www.example.com'), isTrue);
      expect(looksLikeUrl('mailto:foo@example.com'), isTrue);
      expect(looksLikeUrl('ftp://files.example.com'), isTrue);
    });

    test('rejects empty / whitespace / sentences', () {
      expect(looksLikeUrl(''), isFalse);
      expect(looksLikeUrl('   '), isFalse);
      expect(looksLikeUrl('hello world'), isFalse);
      expect(looksLikeUrl('see https://x.com later'), isFalse,
          reason: 'spaces disqualify');
      expect(looksLikeUrl('multi\nline'), isFalse);
    });

    test('trims surrounding whitespace before testing', () {
      expect(looksLikeUrl('  https://example.com  '), isTrue);
    });
  });
}
