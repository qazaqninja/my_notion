import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/html_to_markdown.dart';

void main() {
  group('HtmlToMarkdown.convert', () {
    test('h1-h6 → ATX headings (h4+ collapsed to ###)', () {
      final out = HtmlToMarkdown.convert(
        '<h1>One</h1><h2>Two</h2><h3>Three</h3><h4>Four</h4>',
      );
      expect(out, contains('# One'));
      expect(out, contains('## Two'));
      expect(out, contains('### Three'));
      expect(out, contains('### Four'));
    });

    test('paragraph → text + blank-line separation', () {
      final out = HtmlToMarkdown.convert(
        '<p>first paragraph</p><p>second paragraph</p>',
      );
      expect(out, contains('first paragraph'));
      expect(out, contains('second paragraph'));
    });

    test('strong / b → **', () {
      final out = HtmlToMarkdown.convert(
          '<p>regular and <strong>bold</strong> and <b>also bold</b></p>');
      expect(out, contains('**bold**'));
      expect(out, contains('**also bold**'));
    });

    test('em / i → *', () {
      final out =
          HtmlToMarkdown.convert('<p>plain <em>em</em> and <i>i</i></p>');
      expect(out, contains('*em*'));
      expect(out, contains('*i*'));
    });

    test('inline code → backticks', () {
      final out = HtmlToMarkdown.convert('<p>use <code>foo()</code></p>');
      expect(out, contains('`foo()`'));
    });

    test('pre+code → fenced block', () {
      final out = HtmlToMarkdown.convert(
        '<pre><code>echo "hi"\nls -la</code></pre>',
      );
      expect(out, contains('```'));
      expect(out, contains('echo "hi"'));
      expect(out, contains('ls -la'));
    });

    test('ul → bulleted list', () {
      final out = HtmlToMarkdown.convert(
          '<ul><li>one</li><li>two</li><li>three</li></ul>');
      expect(out, contains('- one'));
      expect(out, contains('- two'));
      expect(out, contains('- three'));
    });

    test('ol → renumbered list', () {
      final out = HtmlToMarkdown.convert(
          '<ol><li>a</li><li>b</li><li>c</li></ol>');
      expect(out, contains('1. a'));
      expect(out, contains('2. b'));
      expect(out, contains('3. c'));
    });

    test('anchor → markdown link', () {
      final out = HtmlToMarkdown.convert(
        '<p>see <a href="https://x.test">site</a></p>',
      );
      expect(out, contains('[site](https://x.test)'));
    });

    test('img → ![alt](src)', () {
      final out = HtmlToMarkdown.convert(
        '<p><img src="/a.png" alt="cover"></p>',
      );
      expect(out, contains('![cover](/a.png)'));
    });

    test('blockquote → > prefix per line', () {
      final out = HtmlToMarkdown.convert(
        '<blockquote>line a\nline b</blockquote>',
      );
      expect(out, contains('> line a'));
      expect(out, contains('> line b'));
    });

    test('hr → ---', () {
      final out = HtmlToMarkdown.convert('<p>x</p><hr><p>y</p>');
      expect(out, contains('---'));
    });

    test('br → newline', () {
      final out = HtmlToMarkdown.convert('<p>line1<br>line2</p>');
      expect(out, contains('line1'));
      expect(out, contains('line2'));
    });

    test('strips head/script/style', () {
      final out = HtmlToMarkdown.convert('''
<head><title>x</title></head>
<style>body { color: red; }</style>
<script>alert(1)</script>
<p>kept</p>
''');
      expect(out, contains('kept'));
      expect(out, isNot(contains('alert(1)')));
      expect(out, isNot(contains('color: red')));
    });

    test('entity decoding', () {
      final out = HtmlToMarkdown.convert(
          '<p>a &amp; b &lt; c &gt; d &quot;e&quot;</p>');
      expect(out, contains('a & b < c > d "e"'));
    });
  });

  group('HtmlToMarkdown.extractTitle', () {
    test('returns the title tag content', () {
      expect(
        HtmlToMarkdown.extractTitle(
            '<html><head><title>My Page</title></head><body>x</body></html>'),
        'My Page',
      );
    });

    test('returns null when title is missing', () {
      expect(HtmlToMarkdown.extractTitle('<html><body>x</body></html>'),
          isNull);
    });

    test('returns null when title is empty', () {
      expect(
        HtmlToMarkdown.extractTitle(
            '<html><head><title></title></head><body>x</body></html>'),
        isNull,
      );
    });
  });
}
