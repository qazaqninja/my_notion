import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/frontmatter_parser.dart';
import '../../../core/vault_dirs.dart';
import 'markdown_to_html.dart';

/// Walks the vault and writes a `.html` for each `.md`, plus a single
/// stylesheet (`site.css`) at the dest root. Wikilinks resolve to
/// `<ULID>.html` siblings, so the produced folder is a self-contained
/// static site you can drop on any host (or open from disk).
class HtmlExporter {
  const HtmlExporter();

  Future<int> export({required Directory src, required Directory dest}) async {
    if (!src.existsSync()) {
      throw ArgumentError('Source vault not found: ${src.path}');
    }
    await dest.create(recursive: true);
    // Write the stylesheet.
    await File(p.join(dest.path, 'site.css')).writeAsString(_kSiteCss);

    int copied = 0;
    final ulidToTitle = <String, String>{};
    // Pass 1: collect ULID → title so wikilinks can use friendly anchors
    // (we still emit hrefs as ULID.html for stable cross-page navigation).
    await for (final entity in _walk(src)) {
      if (entity is File && entity.path.endsWith('.md')) {
        final parsed = FrontmatterParser.parse(await entity.readAsString());
        final id = parsed.frontmatter.id;
        final title = parsed.frontmatter.title ?? p.basenameWithoutExtension(entity.path);
        if (id != null) ulidToTitle[id] = title;
      }
    }

    await for (final entity in _walk(src)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final raw = await entity.readAsString();
      final parsed = FrontmatterParser.parse(raw);
      final title = parsed.frontmatter.title ??
          p.basenameWithoutExtension(entity.path);
      var body = markdownToHtml(parsed.body);
      // Rewrite wikilink anchors to use titles. The title can be any
      // user-typed string from frontmatter — escape before splicing
      // into the anchor text so '<script>' typed as a title can't
      // inject HTML on the linker page.
      body = body.replaceAllMapped(
        RegExp(r'<a class="wikilink" href="([0-9A-Z]{26})\.html">[0-9A-Z]{26}</a>'),
        (m) {
          final ulid = m.group(1)!;
          final t = ulidToTitle[ulid] ?? ulid;
          return '<a class="wikilink" href="$ulid.html">${_escapeAttr(t)}</a>';
        },
      );

      final id = parsed.frontmatter.id ??
          p.basenameWithoutExtension(entity.path);
      final out = File(p.join(dest.path, '$id.html'));
      await out.parent.create(recursive: true);
      await out.writeAsString(_template(title: title, body: body));
      copied++;
    }

    // Write a tiny index.html with a list of pages.
    final index = StringBuffer();
    index.write('<!doctype html><html><head><meta charset="utf-8">');
    index.write('<title>Vault</title><link rel="stylesheet" href="site.css"></head><body>');
    index.write('<h1>Vault</h1><ul class="index">');
    final sorted = ulidToTitle.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    for (final e in sorted) {
      // e.key is a ULID (alphanumeric), e.value is the user-typed
      // title — escape that before splicing into the index anchor.
      index.write(
          '<li><a href="${e.key}.html">${_escapeAttr(e.value)}</a></li>');
    }
    index.write('</ul></body></html>');
    await File(p.join(dest.path, 'index.html')).writeAsString(index.toString());

    return copied;
  }

  Stream<FileSystemEntity> _walk(Directory dir) async* {
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (kIgnoredVaultDirs.contains(name)) continue;
        yield* _walk(entity);
      } else if (entity is File) {
        yield entity;
      }
    }
  }

  static String _template({required String title, required String body}) {
    // title is a user-typed frontmatter field — escape both the
    // <title> attribute-style usage and the <h1> text-node usage.
    // body is already HTML produced by markdownToHtml (which now
    // pre-escapes every text node via M710) so we splice it as-is.
    final safeTitle = _escapeAttr(title);
    return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$safeTitle</title>
<link rel="stylesheet" href="site.css">
</head>
<body>
<main>
<h1 class="page-title">$safeTitle</h1>
$body
</main>
</body>
</html>
''';
  }

  /// Renders a single page as a fully self-contained HTML document with
  /// the site CSS inlined. Used by the editor's "Export as .html…" kebab
  /// action so the produced file works offline without a sibling stylesheet.
  /// Wikilinks are downgraded to non-link `<span class="wikilink">` pills
  /// since their `<ULID>.html` siblings don't exist in a single-file export.
  static String renderStandalonePage({
    required String title,
    required String body,
  }) {
    var html = markdownToHtml(body);
    html = html.replaceAllMapped(
      RegExp(r'<a class="wikilink" href="[0-9A-Z]{26}\.html">([^<]+)</a>'),
      (m) => '<span class="wikilink">${m.group(1)}</span>',
    );
    return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escapeAttr(title)}</title>
<style>
$_kSiteCss</style>
</head>
<body>
<main>
<h1 class="page-title">${_escapeAttr(title)}</h1>
$html
</main>
</body>
</html>
''';
  }

  static String _escapeAttr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const _kSiteCss = '''
body { font: 16px/1.6 -apple-system, system-ui, sans-serif; color: #2a2825;
       background: #faf7f0; margin: 0; }
main { max-width: 720px; margin: 0 auto; padding: 40px 24px; }
.page-title { font-size: 32px; font-weight: 700; margin: 0 0 24px; letter-spacing: -0.5px; }
h1, h2, h3 { color: #1d1c19; line-height: 1.25; }
h2 { font-size: 22px; margin-top: 32px; }
h3 { font-size: 17px; margin-top: 24px; }
p, ul, ol, blockquote { margin: 0 0 14px; }
ul, ol { padding-left: 22px; }
code { background: #efebde; padding: 1px 5px; border-radius: 3px;
       font: 13px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }
pre { background: #1d1c19; color: #efebde; padding: 14px 16px;
      border-radius: 4px; overflow: auto; }
pre code { background: transparent; color: inherit; padding: 0; }
blockquote { border-left: 3px solid #8c9f8b; padding: 4px 14px; color: #59554b; }
.callout { border-left: 3px solid #8c9f8b; padding: 10px 14px; border-radius: 4px;
           background: rgba(140,159,139,0.08); margin: 12px 0; }
.callout-note { border-color: #4A90D9; background: rgba(74,144,217,0.08); }
.callout-tip  { border-color: #55A06A; background: rgba(85,160,106,0.08); }
.callout-warning { border-color: #D08F3D; background: rgba(208,143,61,0.08); }
.callout-caution, .callout-danger { border-color: #CB5A4F; background: rgba(203,90,79,0.08); }
.wikilink { display: inline-block; padding: 1px 6px; background: #efebde;
            border-radius: 3px; text-decoration: none; color: #1d1c19;
            border: 1px solid #d8d3c4; font-size: 13.5px; }
.bookmark, .subpage { display: block; padding: 10px 12px; border: 1px solid #d8d3c4;
                      border-radius: 6px; margin: 8px 0;
                      text-decoration: none; color: #1d1c19; background: #fff; }
a { color: #2a6f44; }
hr { border: none; border-top: 0.5px solid #d8d3c4; margin: 18px 0; }
table { border-collapse: collapse; border: 0.5px solid #d8d3c4; border-radius: 4px;
        overflow: hidden; margin: 14px 0; }
th, td { padding: 6px 10px; border: 0.5px solid #efebde; }
th { background: #efebde; }
figure { margin: 12px 0; text-align: center; }
img { max-width: 100%; border-radius: 4px; }
figcaption { font-size: 12px; color: #7a7468; margin-top: 6px; }
.math { font-family: ui-monospace, Menlo, monospace; padding: 12px;
        background: #efebde; border-radius: 4px; margin: 12px 0; }
mark { background: rgba(251,225,154,0.55); color: #3c2f0f; padding: 0 2px;
       border-radius: 2px; }
.index { list-style: none; padding: 0; }
.index li a { display: block; padding: 8px 10px; border: 1px solid #d8d3c4;
              border-radius: 4px; background: #fff; margin: 4px 0;
              text-decoration: none; color: #1d1c19; }
@media (prefers-color-scheme: dark) {
  body { color: #d8d3c4; background: #1d1c19; }
  h1, h2, h3, .page-title { color: #efebde; }
  code, .wikilink { background: #2a2825; color: #d8d3c4; border-color: #3a3833; }
  .bookmark, .subpage, .index li a { background: #2a2825; color: #d8d3c4; border-color: #3a3833; }
  blockquote { color: #a8a195; }
  th { background: #2a2825; }
  th, td { border-color: #3a3833; }
  .math { background: #2a2825; }
}
''';
}
