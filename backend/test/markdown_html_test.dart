import 'package:backend/public/markdown_html.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownHtmlRenderer (E21)', () {
    String render(String md) => MarkdownHtmlRenderer.render(md);

    test('empty input → empty body', () {
      expect(render(''), '');
    });

    test('plain paragraph wraps in <p>', () {
      expect(render('Hello world.'), '<p>Hello world.</p>');
    });

    test('two paragraphs separated by a blank line', () {
      expect(
        render('First.\n\nSecond.'),
        '<p>First.</p>\n<p>Second.</p>',
      );
    });

    test('soft-wrapped lines inside one paragraph join with a space', () {
      expect(
        render('one\ntwo\nthree'),
        '<p>one two three</p>',
      );
    });

    test('# h1 → <h1>', () {
      expect(render('# Title'), '<h1>Title</h1>');
    });

    test('all six heading levels render', () {
      for (var i = 1; i <= 6; i++) {
        expect(
          render('${'#' * i} H$i'),
          '<h$i>H$i</h$i>',
        );
      }
    });

    test('unordered list', () {
      expect(
        render('- a\n- b\n- c'),
        '<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>',
      );
    });

    test('ordered list', () {
      expect(
        render('1. a\n2. b\n3. c'),
        '<ol>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ol>',
      );
    });

    test('task list checkboxes render', () {
      expect(
        render('- [ ] todo\n- [x] done'),
        // Disabled checkbox + label, no JS.
        '<ul>\n'
        '<li><input type="checkbox" disabled> todo</li>\n'
        '<li><input type="checkbox" disabled checked> done</li>\n'
        '</ul>',
      );
    });

    test('blockquote', () {
      expect(
        render('> quote me'),
        '<blockquote>quote me</blockquote>',
      );
    });

    test('horizontal rule', () {
      expect(render('---'), '<hr>');
    });

    test('fenced code block preserves whitespace + escapes content', () {
      expect(
        render('```\nint x = 1;\nint <y> = 2;\n```'),
        '<pre><code>int x = 1;\nint &lt;y&gt; = 2;</code></pre>',
      );
    });

    test('fenced code block with language hint adds class', () {
      expect(
        render('```dart\nvoid main() {}\n```'),
        '<pre><code class="language-dart">void main() {}</code></pre>',
      );
    });

    test('inline bold + italic + strike', () {
      expect(
        render('**bold** _italic_ ~~strike~~'),
        '<p><strong>bold</strong> <em>italic</em> <s>strike</s></p>',
      );
    });

    test('inline code', () {
      expect(
        render('use `flutter test` to run'),
        '<p>use <code>flutter test</code> to run</p>',
      );
    });

    test('link rewrites to anchor with rel=nofollow', () {
      expect(
        render('see [docs](https://example.com)'),
        '<p>see <a href="https://example.com" rel="nofollow">docs</a></p>',
      );
    });

    test('image renders <img>', () {
      expect(
        render('![alt](https://example.com/a.png)'),
        '<p><img alt="alt" src="https://example.com/a.png"></p>',
      );
    });

    test('wikilink renders as plain text to avoid cross-vault leakage', () {
      expect(
        render('see [[01HX0V0000000000000000000A]] for details'),
        '<p>see 01HX0V0000000000000000000A for details</p>',
      );
    });

    test('HTML-escapes script tags in body text', () {
      expect(
        render('<script>alert(1)</script>'),
        '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>',
      );
    });

    test('HTML-escapes amp + angle in headings', () {
      expect(
        render('# tom & jerry < kids'),
        '<h1>tom &amp; jerry &lt; kids</h1>',
      );
    });

    test('strips YAML frontmatter', () {
      expect(
        render('---\nid: 01HX0V0000000000000000000A\npublic: true\n---\n# Hello\n'),
        '<h1>Hello</h1>',
      );
    });

    test('mixed document renders block-by-block', () {
      const md = '# Title\n\n'
          'A paragraph with **bold**.\n\n'
          '- one\n- two\n\n'
          '```dart\nfinal x = 1;\n```\n\n'
          '> quoted';
      const expected = '<h1>Title</h1>\n'
          '<p>A paragraph with <strong>bold</strong>.</p>\n'
          '<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n'
          '<pre><code class="language-dart">final x = 1;</code></pre>\n'
          '<blockquote>quoted</blockquote>';
      expect(render(md), expected);
    });
  });
}
