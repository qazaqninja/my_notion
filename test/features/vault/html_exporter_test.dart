import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/html_exporter.dart';
import 'package:my_notion/features/vault/data/markdown_to_html.dart';
import 'package:path/path.dart' as p;

void main() {
  group('markdownToHtml', () {
    test('paragraph + emphasis + wikilink + url', () {
      final html = markdownToHtml('Hello **bold** *italic* `code` https://x.com');
      expect(html, contains('<strong>bold</strong>'));
      expect(html, contains('<em>italic</em>'));
      expect(html, contains('<code>code</code>'));
      expect(html, contains('<a href="https://x.com"'));
    });

    test('headings', () {
      final html = markdownToHtml('# H1\n## H2\n### H3');
      expect(html, contains('<h1>H1</h1>'));
      expect(html, contains('<h2>H2</h2>'));
      expect(html, contains('<h3>H3</h3>'));
    });

    test('lists with checkbox', () {
      final html = markdownToHtml('- [ ] todo\n- [x] done\n- plain');
      expect(html, contains('type="checkbox"'));
      expect(html, contains('checked'));
      expect(html, contains('<li>plain</li>'));
    });

    test('ordered list', () {
      final html = markdownToHtml('1. one\n2. two');
      expect(html, contains('<ol>'));
      expect(html, contains('<li>one</li>'));
      expect(html, contains('<li>two</li>'));
    });

    test('blockquote → blockquote', () {
      final html = markdownToHtml('> hi');
      expect(html, contains('<blockquote>hi</blockquote>'));
    });

    test('callout → div.callout-<kind>', () {
      final html = markdownToHtml('> [!NOTE]\n> body');
      expect(html, contains('callout-note'));
      expect(html, contains('body'));
    });

    test('fenced code', () {
      final html = markdownToHtml('```dart\nvoid f() {}\n```');
      expect(html, contains('<pre><code class="lang-dart"'));
      expect(html, contains('void f() {}'));
    });

    test('table', () {
      final html = markdownToHtml('| a | b |\n| --- | --- |\n| 1 | 2 |');
      expect(html, contains('<table>'));
      expect(html, contains('<th>a</th>'));
      expect(html, contains('<td>1</td>'));
    });

    test('standalone image → figure', () {
      final html = markdownToHtml('![alt](pic.png)');
      expect(html, contains('<img src="pic.png"'));
      expect(html, contains('<figcaption>alt</figcaption>'));
    });

    test('highlight ==text== → <mark>', () {
      final html = markdownToHtml('I want to ==highlight this==.');
      expect(html, contains('<mark>highlight this</mark>'));
    });

    test('subscript ~text~ → <sub>', () {
      final html = markdownToHtml('Water is H~2~O.');
      expect(html, contains('H<sub>2</sub>O'));
    });

    test('superscript ^text^ → <sup>', () {
      final html = markdownToHtml('E = mc^2^.');
      expect(html, contains('mc<sup>2</sup>'));
    });

    test('footnote ref [^id] → <sup class="footnote-ref">', () {
      final html = markdownToHtml('See [^1] for details.');
      expect(html, contains('<sup class="footnote-ref">[1]</sup>'));
    });

    test('strikethrough wins over subscript for the same `~~`', () {
      final html = markdownToHtml('~~struck~~ vs ~sub~');
      expect(html, contains('<del>struck</del>'));
      expect(html, contains('<sub>sub</sub>'));
    });

    test('escapes HTML in fenced code', () {
      final html = markdownToHtml('```\n<script>\n```');
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>')));
    });

    test('XSS: escapes `"` in autolinked URL attribute (M709)', () {
      // A URL containing '"' would close the href attribute and
      // inject arbitrary HTML if not escaped.
      final html = markdownToHtml('See http://evil.example/"><script>alert(1)</script>');
      expect(html, isNot(contains('<script>')),
          reason: 'unescaped `"` would let an attacker inject script');
      expect(html, contains('&quot;'));
    });

    test('XSS: escapes `"` in standalone-URL bookmark href (M707/M709)', () {
      // Standalone URL on its own line takes the "bookmark" card path.
      final html = markdownToHtml('http://evil.example/q="bad');
      expect(html, isNot(contains('href="http://evil.example/q="bad')));
      expect(html, contains('&quot;'));
    });

    test('XSS: escapes `"` in standalone image src (M706/M709)', () {
      final html = markdownToHtml('![alt](http://evil.example/x.png"><script>)');
      expect(html, isNot(contains('<script>')));
      // The src must have its '"' encoded.
      expect(html, contains('&quot;'));
    });

    test('XSS: escapes `"` and `<` in code-fence language hint (M708/M709)',
        () {
      final html =
          markdownToHtml('```dart"><script>alert(1)</script>\nx\n```');
      expect(html, isNot(contains('<script>alert(1)</script>')));
      // The lang label is interpolated into a class attribute.
      expect(html, contains('class="lang-dart&quot;&gt;&lt;script&gt;'));
    });
  });

  test('HtmlExporter writes one .html per .md plus index + css', () async {
    final src = await Directory.systemTemp.createTemp('quill_html_src_');
    final dest = await Directory.systemTemp.createTemp('quill_html_dst_');
    await File(p.join(src.path, 'foo.md')).writeAsString(
      '---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B\ntitle: Foo\n---\n# Heading\n\nHello world.\n',
    );
    await File(p.join(src.path, 'bar.md')).writeAsString(
      '---\nid: 01HX0VEY5T6K7R9X4Y8Z0A3D4G\ntitle: Bar\n---\nSee [[01HX0V9R5N6E8L3P7Q8S9U2X4B]].\n',
    );

    final n = await const HtmlExporter().export(src: src, dest: dest);
    expect(n, 2);
    expect(await File(p.join(dest.path, 'site.css')).exists(), isTrue);
    expect(await File(p.join(dest.path, 'index.html')).exists(), isTrue);
    final foo =
        await File(p.join(dest.path, '01HX0V9R5N6E8L3P7Q8S9U2X4B.html'))
            .readAsString();
    expect(foo, contains('<title>Foo</title>'));
    expect(foo, contains('<h1>Heading</h1>'));
    expect(foo, contains('<p>Hello world.</p>'));

    final bar =
        await File(p.join(dest.path, '01HX0VEY5T6K7R9X4Y8Z0A3D4G.html'))
            .readAsString();
    // Wikilink rewritten to the target's title.
    expect(bar, contains('>Foo</a>'));
    expect(bar, contains('href="01HX0V9R5N6E8L3P7Q8S9U2X4B.html"'));

    await src.delete(recursive: true);
    await dest.delete(recursive: true);
  });

  test('multi-page export preserves #anchor in wikilink href (M779)', () async {
    final src = await Directory.systemTemp.createTemp('quill_html_anchor_src_');
    final dest = await Directory.systemTemp.createTemp('quill_html_anchor_dst_');
    await File(p.join(src.path, 'foo.md')).writeAsString(
      '---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B\ntitle: Foo\n---\n## install\n',
    );
    await File(p.join(src.path, 'bar.md')).writeAsString(
      '---\nid: 01HX0VEY5T6K7R9X4Y8Z0A3D4G\ntitle: Bar\n---\n'
      'See [[01HX0V9R5N6E8L3P7Q8S9U2X4B#install]] for setup.\n',
    );

    await const HtmlExporter().export(src: src, dest: dest);
    final bar = await File(
            p.join(dest.path, '01HX0VEY5T6K7R9X4Y8Z0A3D4G.html'))
        .readAsString();
    // The anchor survives the title-rewrite pass — the link's href
    // should be `<ulid>.html#install` and the anchor text is the
    // target page's title.
    expect(bar,
        contains('href="01HX0V9R5N6E8L3P7Q8S9U2X4B.html#install">Foo</a>'));

    await src.delete(recursive: true);
    await dest.delete(recursive: true);
  });

  test('XSS: multi-page export escapes title in <title>, <h1>, index, and '
      'wikilink anchor (M711)', () async {
    final src = await Directory.systemTemp.createTemp('quill_html_xss_src_');
    final dest = await Directory.systemTemp.createTemp('quill_html_xss_dst_');
    // Page A has a title with a script tag; page B wikilinks to it so
    // the linked-title rewrite path also gets exercised.
    await File(p.join(src.path, 'a.md')).writeAsString('---\n'
        'id: 01HX0V9R5N6E8L3P7Q8S9U2X4B\n'
        'title: "<script>alert(1)</script>"\n'
        '---\nbody of a\n');
    await File(p.join(src.path, 'b.md')).writeAsString('---\n'
        'id: 01HX0VEY5T6K7R9X4Y8Z0A3D4G\n'
        'title: B\n'
        '---\nSee [[01HX0V9R5N6E8L3P7Q8S9U2X4B]].\n');
    await const HtmlExporter().export(src: src, dest: dest);

    final a = await File(
            p.join(dest.path, '01HX0V9R5N6E8L3P7Q8S9U2X4B.html'))
        .readAsString();
    final b = await File(
            p.join(dest.path, '01HX0VEY5T6K7R9X4Y8Z0A3D4G.html'))
        .readAsString();
    final idx =
        await File(p.join(dest.path, 'index.html')).readAsString();

    // No live <script> anywhere. The fixture body contains the literal
    // characters via YAML, so we look for the script form specifically.
    for (final out in [a, b, idx]) {
      expect(out, isNot(contains('<script>alert(1)</script>')),
          reason: 'title XSS leaked into ${out == a ? "A" : out == b ? "B" : "index"}');
    }
    // The escaped form must appear in the title element + h1 + wikilink
    // anchor + index list entry.
    expect(a, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(b, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(idx, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));

    await src.delete(recursive: true);
    await dest.delete(recursive: true);
  });

  group('HtmlExporter.renderStandalonePage', () {
    test('contains title, body and embedded CSS', () {
      final html = HtmlExporter.renderStandalonePage(
        title: 'Test',
        body: '# Heading\n\nBody text.',
      );
      expect(html, contains('<title>Test</title>'));
      expect(html, contains('class="page-title">Test</h1>'));
      expect(html, contains('<h1>Heading</h1>'));
      expect(html, contains('<p>Body text.</p>'));
      // CSS inlined inside <style> tags rather than via stylesheet ref.
      expect(html, contains('<style>'));
      expect(html, contains('body { font:'));
      expect(html, isNot(contains('rel="stylesheet"')));
    });

    test('downgrades wikilinks to non-link spans (no broken hrefs)', () {
      final html = HtmlExporter.renderStandalonePage(
        title: 'P',
        body: 'See [[01HX0V9R5N6E8L3P7Q8S9U2X4B]].',
      );
      expect(html, contains('<span class="wikilink">'));
      expect(html, isNot(contains('href="01HX0V9R5N6E8L3P7Q8S9U2X4B.html"')));
    });

    test('downgrades anchored wikilinks too (M779)', () {
      // `[[ULID#anchor]]` produces an `<a href="ULID.html#anchor">`
      // first via markdownToHtml; renderStandalonePage strips it down
      // to a non-link span because no sibling file exists in a single-
      // file export. The anchor on the href would otherwise leak into
      // the source page and break offline-share.
      final html = HtmlExporter.renderStandalonePage(
        title: 'P',
        body: 'See [[01HX0V9R5N6E8L3P7Q8S9U2X4B#install]].',
      );
      expect(html, contains('<span class="wikilink">'));
      expect(html, isNot(contains('href="')),
          reason: 'anchored hrefs must be stripped, not leak as live links');
    });

    test('escapes < > & " in title attribute', () {
      final html = HtmlExporter.renderStandalonePage(
        title: 'A & B <c> "d"',
        body: 'x',
      );
      expect(html, contains('<title>A &amp; B &lt;c&gt; &quot;d&quot;</title>'));
    });
  });
}
