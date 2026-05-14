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

    test('escapes HTML in fenced code', () {
      final html = markdownToHtml('```\n<script>\n```');
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>')));
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

    test('escapes < > & " in title attribute', () {
      final html = HtmlExporter.renderStandalonePage(
        title: 'A & B <c> "d"',
        body: 'x',
      );
      expect(html, contains('<title>A &amp; B &lt;c&gt; &quot;d&quot;</title>'));
    });
  });
}
