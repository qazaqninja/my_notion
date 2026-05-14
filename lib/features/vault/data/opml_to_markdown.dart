/// Minimal OPML → CommonMark converter for Workflowy / outliner exports.
///
/// OPML is XML with nested `outline text="..."` elements. We render
/// the tree as a nested bullet list — parent items become `- text`,
/// children one indent (two spaces) deeper. `_note` attributes are
/// emitted on the next line under the bullet, slightly indented.
///
/// Dependency-free regex parser — handles the common 95% (well-formed
/// OPML 1/2 with `text=` attribute, optional `_note=` second line per
/// node). Doesn't validate XML, doesn't handle CDATA, doesn't decode
/// every entity — for Quill imports this is good enough; an external
/// `xml` package can replace this if real users hit limits.
library;

class OpmlToMarkdown {
  const OpmlToMarkdown._();

  /// Convert [opml] to a CommonMark body. Returns an empty string when
  /// the document has no `<body>` or no outline children.
  static String convert(String opml) {
    final bodyMatch = RegExp(r'<body\b[^>]*>([\s\S]*?)</body>',
            caseSensitive: false)
        .firstMatch(opml);
    if (bodyMatch == null) return '';
    final body = bodyMatch.group(1) ?? '';
    final lines = <String>[];
    _walk(body, 0, lines);
    return lines.join('\n');
  }

  /// Extract `<title>` from `<head>`. Returns null when missing/empty.
  static String? extractTitle(String opml) {
    final m = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
        .firstMatch(opml);
    if (m == null) return null;
    final t = _decode(m.group(1) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// Tokenize [fragment] into open/close/self-closing outline events
  /// and recurse depth-first. Indent level is two-space per nesting.
  static void _walk(String fragment, int depth, List<String> out) {
    final tokenRe = RegExp(
        r'<outline\b([^>]*?)/>|<outline\b([^>]*?)>|</outline\s*>',
        caseSensitive: false);
    int pos = 0;
    var d = depth;
    while (pos < fragment.length) {
      final m = tokenRe.firstMatch(fragment.substring(pos));
      if (m == null) break;
      final attrs = m.group(1) ?? m.group(2);
      if (attrs == null) {
        // closing tag
        d = (d - 1).clamp(0, 1 << 30);
        pos += m.end;
        continue;
      }
      final text = _attr(attrs, 'text') ?? '';
      final note = _attr(attrs, '_note');
      if (text.isNotEmpty || note != null) {
        final indent = '  ' * d;
        out.add('$indent- ${_decode(text)}');
        if (note != null && note.trim().isNotEmpty) {
          out.add('$indent  ${_decode(note)}');
        }
      }
      // self-closing → no depth change. Open tag → next nodes are children.
      final isSelfClosing = m.group(1) != null;
      if (!isSelfClosing) d += 1;
      pos += m.end;
    }
  }

  /// Extract an attribute value from a token like `text="foo" _note="bar"`.
  /// Tolerates both double and single quotes. Returns null when absent.
  static String? _attr(String attrs, String name) {
    final re = RegExp('$name=' r'''(?:"([^"]*)"|'([^']*)')''',
        caseSensitive: false);
    final m = re.firstMatch(attrs);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }

  static String _decode(String s) {
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
