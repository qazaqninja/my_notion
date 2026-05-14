/// Minimal markdown → HTML converter, covering the block kinds Quill's
/// MarkdownRenderer handles: h1/h2/h3, paragraphs (with inline emphasis +
/// wikilinks + URLs + inline code), unordered + ordered + todo lists,
/// blockquotes (with GFM callouts), horizontal rule, fenced code blocks,
/// math (passes through `$$ ... $$` raw so the user can wire KaTeX in
/// their published site), pipe tables, images, sub-page cards, bookmark
/// cards.
///
/// Pure-Dart, no external dependency. The output is semantic HTML with
/// classes that match the conventions in `assets/site.css` (which the
/// exporter writes alongside).
library;

String markdownToHtml(String body) {
  final lines = body.split('\n');
  final out = StringBuffer();
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];

    // Code fence
    if (line.startsWith('```')) {
      final lang = line.substring(3).trim();
      final buf = StringBuffer();
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(_escape(lines[i]));
        i++;
      }
      if (i < lines.length) i++; // closing ```
      out.write('<pre><code class="lang-$lang">${buf.toString()}</code></pre>\n');
      continue;
    }

    // Math fence
    if (line.startsWith(r'$$')) {
      final stripped = line.substring(2);
      final closeIdx = stripped.lastIndexOf(r'$$');
      if (closeIdx >= 0) {
        out.write(
            '<div class="math">\$\$${_escape(stripped.substring(0, closeIdx).trim())}\$\$</div>\n');
        i++;
        continue;
      }
      final buf = StringBuffer();
      if (stripped.isNotEmpty) buf.write(stripped);
      i++;
      while (i < lines.length && !lines[i].trim().startsWith(r'$$')) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(lines[i]);
        i++;
      }
      if (i < lines.length) i++;
      out.write(
          '<div class="math">\$\$${_escape(buf.toString().trim())}\$\$</div>\n');
      continue;
    }

    // GFM pipe table
    if (line.contains('|') &&
        i + 1 < lines.length &&
        RegExp(r'^\s*\|?[\s\-:|]+\|[\s\-:|]+\s*$').hasMatch(lines[i + 1])) {
      final rows = <List<String>>[_splitTableRow(line)];
      i += 2;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          lines[i].contains('|')) {
        rows.add(_splitTableRow(lines[i]));
        i++;
      }
      out.write('<table>\n');
      for (var r = 0; r < rows.length; r++) {
        final tag = r == 0 ? 'th' : 'td';
        out.write('  <tr>');
        for (final c in rows[r]) {
          out.write('<$tag>${_inline(c)}</$tag>');
        }
        out.write('</tr>\n');
      }
      out.write('</table>\n');
      continue;
    }

    // Headings
    if (line.startsWith('### ')) {
      out.write('<h3>${_inline(line.substring(4))}</h3>\n');
      i++;
      continue;
    }
    if (line.startsWith('## ')) {
      out.write('<h2>${_inline(line.substring(3))}</h2>\n');
      i++;
      continue;
    }
    if (line.startsWith('# ')) {
      out.write('<h1>${_inline(line.substring(2))}</h1>\n');
      i++;
      continue;
    }

    // Blockquote / callout
    if (line.startsWith('> ') || line == '>') {
      final buf = <String>[];
      while (i < lines.length && (lines[i].startsWith('> ') || lines[i] == '>')) {
        buf.add(lines[i] == '>' ? '' : lines[i].substring(2));
        i++;
      }
      final first = buf.isNotEmpty ? buf.first : '';
      final m = RegExp(r'^\[!(\w+)\]\s*(.*)$').firstMatch(first);
      if (m != null) {
        final kind = m.group(1)!.toLowerCase();
        final rest = m.group(2) ?? '';
        final body = (rest.isEmpty
                ? buf.skip(1)
                : [rest, ...buf.skip(1)])
            .join('\n');
        out.write(
            '<div class="callout callout-$kind">${_inline(body.trim())}</div>\n');
      } else {
        out.write('<blockquote>${_inline(buf.join('\n'))}</blockquote>\n');
      }
      continue;
    }

    // Horizontal rule
    if (line.trim() == '---' || line.trim() == '***' || line.trim() == '___') {
      out.write('<hr/>\n');
      i++;
      continue;
    }

    // Unordered list (with checkbox support)
    if (line.startsWith('- ') || line.startsWith('* ')) {
      out.write('<ul>\n');
      while (i < lines.length &&
          (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
        final item = lines[i].substring(2);
        final cb = RegExp(r'^\[([ xX])\]\s+').firstMatch(item);
        if (cb != null) {
          final checked = cb.group(1)!.toLowerCase() == 'x';
          out.write(
              '  <li><input type="checkbox" disabled${checked ? ' checked' : ''}/> ${_inline(item.substring(cb.end))}</li>\n');
        } else {
          out.write('  <li>${_inline(item)}</li>\n');
        }
        i++;
      }
      out.write('</ul>\n');
      continue;
    }

    // Ordered list
    if (RegExp(r'^\d+\.\s').hasMatch(line)) {
      out.write('<ol>\n');
      while (i < lines.length && RegExp(r'^\d+\.\s').hasMatch(lines[i])) {
        final item = lines[i].replaceFirst(RegExp(r'^\d+\.\s'), '');
        out.write('  <li>${_inline(item)}</li>\n');
        i++;
      }
      out.write('</ol>\n');
      continue;
    }

    // Blank → just skip
    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    // Otherwise paragraph
    final buf = StringBuffer(line);
    i++;
    while (i < lines.length &&
        lines[i].trim().isNotEmpty &&
        !_isBlockStartHtml(lines[i])) {
      buf.write('\n');
      buf.write(lines[i]);
      i++;
    }
    final text = buf.toString();
    // Standalone image
    final imageMatch =
        RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(text.trim());
    if (imageMatch != null) {
      out.write(
          '<figure><img src="${imageMatch.group(2)}" alt="${_escape(imageMatch.group(1) ?? '')}"/>${imageMatch.group(1)?.isNotEmpty == true ? '<figcaption>${_escape(imageMatch.group(1)!)}</figcaption>' : ''}</figure>\n');
      continue;
    }
    // Standalone wikilink
    final wiki = RegExp(r'^\[\[([0-9A-Z]{26})\]\]$')
        .firstMatch(text.trim());
    if (wiki != null) {
      out.write(
          '<a class="subpage" href="${wiki.group(1)}.html">${wiki.group(1)}</a>\n');
      continue;
    }
    // Standalone URL
    final url =
        RegExp(r'^(https?://[^\s\<\>\[\]\(\)]+)$').firstMatch(text.trim());
    if (url != null) {
      out.write(
          '<a class="bookmark" href="${url.group(1)}" target="_blank">${url.group(1)}</a>\n');
      continue;
    }
    out.write('<p>${_inline(text)}</p>\n');
  }
  return out.toString();
}

bool _isBlockStartHtml(String line) {
  return line.startsWith('```') ||
      line.startsWith(r'$$') ||
      line.startsWith('# ') ||
      line.startsWith('## ') ||
      line.startsWith('### ') ||
      line.startsWith('- ') ||
      line.startsWith('* ') ||
      line.startsWith('> ') ||
      line == '>' ||
      RegExp(r'^\d+\.\s').hasMatch(line) ||
      line.contains('|') && line.trim().startsWith('|') ||
      line.trim() == '---';
}

List<String> _splitTableRow(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) => c.trim()).toList();
}

String _escape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Inline pass: bold / italic / strike / code / wikilinks / URLs.
String _inline(String s) {
  // Wikilinks first (they're greedy delimiters).
  s = s.replaceAllMapped(
    RegExp(r'\[\[([0-9A-Z]{26})\]\]'),
    (m) => '<a class="wikilink" href="${m.group(1)}.html">${m.group(1)}</a>',
  );
  // Inline code (escape inside).
  s = s.replaceAllMapped(
    RegExp('`([^`\n]+)`'),
    (m) => '<code>${_escape(m.group(1)!)}</code>',
  );
  // Bold
  s = s.replaceAllMapped(
    RegExp(r'\*\*([^*\n]+)\*\*'),
    (m) => '<strong>${m.group(1)}</strong>',
  );
  // Italic
  s = s.replaceAllMapped(
    RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
    (m) => '<em>${m.group(1)}</em>',
  );
  s = s.replaceAllMapped(
    RegExp(r'_([^_\n]+)_'),
    (m) => '<em>${m.group(1)}</em>',
  );
  // Strikethrough
  s = s.replaceAllMapped(
    RegExp(r'~~([^~\n]+)~~'),
    (m) => '<del>${m.group(1)}</del>',
  );
  // Subscript ~text~ (Pandoc). Only single `~`s; the strikethrough
  // pass above has already consumed `~~…~~`.
  s = s.replaceAllMapped(
    RegExp(r'(?<!~)~([^~\n]+)~(?!~)'),
    (m) => '<sub>${m.group(1)}</sub>',
  );
  // Superscript ^text^ (Pandoc).
  s = s.replaceAllMapped(
    RegExp(r'\^([^\^\n]+)\^'),
    (m) => '<sup>${m.group(1)}</sup>',
  );
  // Highlight  ==text==
  s = s.replaceAllMapped(
    RegExp(r'==([^=\n]+)=='),
    (m) => '<mark>${m.group(1)}</mark>',
  );
  // Bare URLs
  s = s.replaceAllMapped(
    RegExp(r'(?<!["=])(https?://[^\s\<\>\[\]\(\)]+)'),
    (m) => '<a href="${m.group(1)}" target="_blank">${m.group(1)}</a>',
  );
  return s;
}
