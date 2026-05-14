/// Word .docx (OOXML ZIP) → CommonMark converter.
///
/// .docx is a ZIP with `word/document.xml` carrying the body. We unzip,
/// then regex-walk the `<w:p>` (paragraph) and `<w:r>` (run) elements
/// to emit markdown. Supported:
///
/// - Headings via `<w:pStyle w:val="Heading1|Heading2|Heading3">` → `#`/`##`/`###`
/// - Bold via `<w:b/>` inside `<w:rPr>` → `**`
/// - Italic via `<w:i/>` → `*`
/// - Underline via `<w:u/>` → no markdown equivalent, ignored
/// - Strikethrough via `<w:strike/>` → `~~`
/// - Lists via `<w:numPr><w:ilvl w:val="N">` → `- ` indented two spaces per level
/// - Hyperlinks via `<w:hyperlink r:id="...">` are kept as plain text (link
///   target resolution requires walking the relationships file — out of
///   scope for v1).
///
/// Tables, images, drawings, fields, citations, and most macros are
/// dropped — they need a richer parser. Good enough for "I copied a
/// document into Word and want it in Quill" cases.
library;

import 'package:archive/archive.dart';

class DocxToMarkdown {
  const DocxToMarkdown._();

  /// Convert raw .docx file bytes (a ZIP) to a CommonMark body.
  /// Returns an empty string when the document.xml is missing or
  /// malformed.
  static String convert(List<int> bytes) {
    final ArchiveFile? doc;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      doc = archive.findFile('word/document.xml');
    } catch (_) {
      return '';
    }
    if (doc == null) return '';
    final xml = String.fromCharCodes(doc.content as List<int>);
    return _walkBody(xml);
  }

  /// Top-level driver — finds the `<w:body>` and emits a paragraph per
  /// `<w:p>`. Joins with a blank line so paragraphs render separately.
  static String _walkBody(String xml) {
    final bodyMatch = RegExp(r'<w:body\b[^>]*>([\s\S]*?)</w:body>',
            caseSensitive: false)
        .firstMatch(xml);
    final body = bodyMatch?.group(1) ?? xml;
    final lines = <String>[];
    for (final p
        in RegExp(r'<w:p\b[^>]*>([\s\S]*?)</w:p>', caseSensitive: false)
            .allMatches(body)) {
      final emitted = _emitParagraph(p.group(1) ?? '');
      if (emitted != null) lines.add(emitted);
    }
    return lines.join('\n\n').trim();
  }

  /// Emit one markdown line for a single `<w:p>...</w:p>` payload.
  /// Returns null when the paragraph is structurally empty so callers
  /// don't get stray blank gaps.
  static String? _emitParagraph(String paragraph) {
    // pStyle → heading prefix.
    final styleMatch = RegExp(
            r'''<w:pStyle\s+w:val=["']([^"']+)["']\s*/?>''',
            caseSensitive: false)
        .firstMatch(paragraph);
    final style = styleMatch?.group(1)?.toLowerCase() ?? '';
    final isH1 = style == 'heading1' || style == 'title';
    final isH2 = style == 'heading2' || style == 'subtitle';
    final isH3 = style.startsWith('heading') && !isH1 && !isH2;
    // numPr → list bullet.
    final listMatch = RegExp(r'<w:numPr>', caseSensitive: false)
        .firstMatch(paragraph);
    final ilvlMatch = RegExp(
            r'''<w:ilvl\s+w:val=["'](\d+)["']\s*/?>''',
            caseSensitive: false)
        .firstMatch(paragraph);
    final isList = listMatch != null;
    final level =
        isList ? int.tryParse(ilvlMatch?.group(1) ?? '0') ?? 0 : 0;
    // Collect runs.
    final text = _collectRuns(paragraph);
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (isH1) return '# $trimmed';
    if (isH2) return '## $trimmed';
    if (isH3) return '### $trimmed';
    if (isList) return '${'  ' * level}- $trimmed';
    return trimmed;
  }

  /// Walk the `<w:r>` elements in a paragraph; pull each one's `<w:t>`
  /// text plus formatting toggles (b/i/strike) and emit markdown
  /// inline syntax.
  static String _collectRuns(String paragraph) {
    final buf = StringBuffer();
    final runRe = RegExp(r'<w:r\b[^>]*>([\s\S]*?)</w:r>',
        caseSensitive: false);
    for (final r in runRe.allMatches(paragraph)) {
      final inner = r.group(1) ?? '';
      final rPrMatch =
          RegExp(r'<w:rPr>([\s\S]*?)</w:rPr>', caseSensitive: false)
              .firstMatch(inner);
      final rPr = rPrMatch?.group(1) ?? '';
      final bold = RegExp(r'<w:b\s*/>|<w:b\s+[^>]*/>',
              caseSensitive: false)
          .hasMatch(rPr);
      final italic = RegExp(r'<w:i\s*/>|<w:i\s+[^>]*/>',
              caseSensitive: false)
          .hasMatch(rPr);
      final strike =
          RegExp(r'<w:strike\s*/>', caseSensitive: false).hasMatch(rPr);
      final isCode = RegExp(r'''<w:rFonts\s+[^>]*w:ascii=["'](Courier|Consolas|Menlo)''',
              caseSensitive: false)
          .hasMatch(rPr);
      // Text body — walk w:t / w:tab / w:br tokens in source order so
      // `a<tab>b<br>c` reads as `a b c` instead of `abc  `.
      final textBuf = StringBuffer();
      final tokRe = RegExp(
          r'<w:t\b[^>]*>([\s\S]*?)</w:t>|<w:tab\s*/>|<w:br\s*/>',
          caseSensitive: false);
      for (final m in tokRe.allMatches(inner)) {
        final txt = m.group(1);
        if (txt != null) {
          textBuf.write(_decode(txt));
        } else {
          // tab or br → single space.
          textBuf.write(' ');
        }
      }
      var t = textBuf.toString();
      if (t.isEmpty) continue;
      if (isCode) t = '`$t`';
      if (strike) t = '~~$t~~';
      if (italic) t = '*$t*';
      if (bold) t = '**$t**';
      buf.write(t);
    }
    return buf.toString();
  }

  static String _decode(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
