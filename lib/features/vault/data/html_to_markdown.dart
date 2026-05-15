/// Quill's small, dependency-free HTML → CommonMark converter. Not a
/// full parser — handles the tag set most pasted-from-the-browser
/// content carries: headings (h1-h6), paragraphs, lists, anchors,
/// emphasis, strong, code, pre, blockquote, br, hr, img. Anything
/// unhandled has its tags stripped but text preserved.
///
/// Tradeoff: keeps Quill's pub graph small and the round-trip
/// deterministic — at the cost of skipping fragments like tables and
/// nested structures with attributes. Good enough for "I copied an
/// article and want it as a Quill page" cases; a full converter is
/// future work if real users hit limitations.
library;

class HtmlToMarkdown {
  const HtmlToMarkdown._();

  /// Convert [html] into a CommonMark body string.
  static String convert(String html) {
    var s = html;
    // Strip <head>...</head>, <script>, <style> — drop their content.
    s = _stripBlock(s, 'head');
    s = _stripBlock(s, 'script');
    s = _stripBlock(s, 'style');
    s = _stripBlock(s, 'noscript');

    // Block-level tags → markdown line forms. Order matters: do nested
    // / specific tags first so the wider replacements don't eat them.
    s = _replaceTag(s, 'h1', (inner) => '\n# ${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'h2', (inner) => '\n## ${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'h3', (inner) => '\n### ${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'h4', (inner) => '\n### ${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'h5', (inner) => '\n### ${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'h6', (inner) => '\n### ${_inline(inner).trim()}\n\n');

    // pre + code → fenced block. <pre><code>…</code></pre> is the most
    // common shape; <pre> on its own falls back to plain fence.
    s = s.replaceAllMapped(
      RegExp(r'<pre[^>]*>\s*<code[^>]*>([\s\S]*?)</code>\s*</pre>',
          caseSensitive: false),
      (m) => '\n```\n${_decode(m.group(1) ?? '').trim()}\n```\n\n',
    );
    s = _replaceTag(
        s, 'pre', (inner) => '\n```\n${_decode(inner).trim()}\n```\n\n');

    // Lists. Convert <li> first, then strip the surrounding <ul>/<ol>.
    s = s.replaceAllMapped(
      RegExp(r'<ul[^>]*>([\s\S]*?)</ul>', caseSensitive: false),
      (m) => '\n${_unorderedList(m.group(1) ?? '')}\n',
    );
    s = s.replaceAllMapped(
      RegExp(r'<ol[^>]*>([\s\S]*?)</ol>', caseSensitive: false),
      (m) => '\n${_orderedList(m.group(1) ?? '')}\n',
    );

    // Blockquote
    s = _replaceTag(
      s,
      'blockquote',
      (inner) {
        final body = _inline(inner).trim();
        return '\n${body.split('\n').map((l) => '> $l').join('\n')}\n\n';
      },
    );

    // Paragraph & divs → blank line separated text.
    s = _replaceTag(s, 'p', (inner) => '\n${_inline(inner).trim()}\n\n');
    s = _replaceTag(s, 'div', (inner) => '\n${_inline(inner).trim()}\n');

    // Standalone <br> and <hr>.
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n');

    // Inline pass for whatever's left at the top level.
    s = _inline(s);

    // Decode entities & collapse 3+ blank lines.
    s = _decode(s);
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return '$s\n';
  }

  static String _stripBlock(String s, String tag) => s.replaceAll(
      RegExp('<$tag\\b[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false), '');

  static String _replaceTag(
      String s, String tag, String Function(String inner) f) {
    return s.replaceAllMapped(
      RegExp('<$tag\\b[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false),
      (m) => f(m.group(1) ?? ''),
    );
  }

  /// Inline-only conversions: anchors → `[text](url)`, emphasis → `*…*`,
  /// strong → `**…**`, code → backticks, img → `![alt](src)`. Any other
  /// tag has its opener + closer stripped while keeping the text.
  static String _inline(String s) {
    var out = s;
    // <a href="..."> text </a> — accept both `"…"` and `'…'` quote
    // styles for href. The img branch already matched both, the
    // anchor branch only matched `"…"` and silently lost any link
    // whose author used single quotes (common in hand-written HTML).
    out = out.replaceAllMapped(
      RegExp(r'''<a\s+[^>]*href=["']([^"']*)["'][^>]*>([\s\S]*?)</a>''',
          caseSensitive: false),
      (m) =>
          '[${_escapeAlt(_stripInline(m.group(2) ?? '').trim())}](${m.group(1)})',
    );
    // <img src="..." alt="...">
    out = out.replaceAllMapped(
      RegExp(r'''<img\s+[^>]*?src=["']([^"']*)["'][^>]*>''',
          caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        final altMatch =
            RegExp(r'''alt=["']([^"']*)["']''').firstMatch(m.group(0)!);
        final alt = altMatch?.group(1) ?? '';
        return '![${_escapeAlt(alt)}]($src)';
      },
    );
    // <strong> / <b>
    out = out.replaceAllMapped(
      RegExp(r'<(strong|b)\b[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
      (m) => '**${_stripInline(m.group(2) ?? '')}**',
    );
    // <em> / <i>
    out = out.replaceAllMapped(
      RegExp(r'<(em|i)\b[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
      (m) => '*${_stripInline(m.group(2) ?? '')}*',
    );
    // <code> (not inside <pre>, which was handled earlier).
    out = out.replaceAllMapped(
      RegExp(r'<code\b[^>]*>([\s\S]*?)</code>', caseSensitive: false),
      (m) => '`${_stripInline(m.group(1) ?? '')}`',
    );
    // <s> / <del> / <strike>
    out = out.replaceAllMapped(
      RegExp(r'<(s|del|strike)\b[^>]*>([\s\S]*?)</\1>',
          caseSensitive: false),
      (m) => '~~${_stripInline(m.group(2) ?? '')}~~',
    );
    // Any remaining tags — strip the open + close, keep inner text.
    out = out.replaceAll(RegExp(r'<[^>]+>'), '');
    return out;
  }

  static String _stripInline(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '');

  /// Escape `[` / `]` / `\` inside markdown link / image alt text so a
  /// converted HTML `<img alt="foo [v2]">` survives as
  /// `![foo \[v2\]](src)` instead of truncating at the first `]`.
  static String _escapeAlt(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');

  static String _unorderedList(String inner) {
    final items = RegExp(r'<li\b[^>]*>([\s\S]*?)</li>', caseSensitive: false)
        .allMatches(inner)
        .map((m) => '- ${_inline(m.group(1) ?? '').trim()}')
        .toList();
    return items.join('\n');
  }

  static String _orderedList(String inner) {
    final raw = RegExp(r'<li\b[^>]*>([\s\S]*?)</li>', caseSensitive: false)
        .allMatches(inner)
        .map((m) => _inline(m.group(1) ?? '').trim())
        .toList();
    return [for (var i = 0; i < raw.length; i++) '${i + 1}. ${raw[i]}']
        .join('\n');
  }

  /// Extract a `<title>` from a complete HTML document, or return null.
  static String? extractTitle(String html) {
    final m = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
        .firstMatch(html);
    if (m == null) return null;
    final t = _decode(m.group(1) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static String _decode(String s) {
    // Minimal entity decoding — the long tail isn't worth a dep here.
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
