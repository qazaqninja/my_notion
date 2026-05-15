import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/markdown/frontmatter_parser.dart';
import '../../../core/vault_dirs.dart';

/// Walks the vault and emits a single PDF file containing every `.md`
/// page (frontmatter title as the page heading, body rendered with the
/// same block kinds as MarkdownRenderer but using pdf-package widgets).
///
/// Math, Mermaid, and embedded images are rendered as raw text — full
/// graphics support is future work. Wikilinks render as the linked page's
/// title (resolved up-front), so cross-references stay readable.
class PdfExporter {
  const PdfExporter();

  Future<int> export({
    required Directory src,
    required File dest,
  }) async {
    if (!src.existsSync()) {
      throw ArgumentError('Source vault not found: ${src.path}');
    }

    // Pass 1: build a ULID → title lookup for wikilink resolution.
    final ulidToTitle = <String, String>{};
    final pages = <_PageData>[];
    await for (final entity in _walk(src)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final raw = await entity.readAsString();
      final parsed = FrontmatterParser.parse(raw);
      final title = parsed.frontmatter.title ??
          p.basenameWithoutExtension(entity.path);
      final id = parsed.frontmatter.id;
      if (id != null) ulidToTitle[id] = title;
      pages.add(_PageData(
        title: title,
        body: parsed.body,
        relativePath: p.relative(entity.path, from: src.path),
      ));
    }

    // Sort by relative path for deterministic page order.
    pages.sort((a, b) => a.relativePath.compareTo(b.relativePath));

    final doc = pw.Document(
      title: 'Vault export',
      creator: 'Quill',
    );

    final theme = _buildTheme();

    for (final page in pages) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginTop: 48,
            marginBottom: 48,
            marginLeft: 56,
            marginRight: 56,
          ),
          theme: theme,
          header: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              page.relativePath,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff8a8275),
              ),
            ),
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff8a8275),
              ),
            ),
          ),
          build: (ctx) =>
              _buildPage(page.title, page.body, ulidToTitle),
        ),
      );
    }

    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(await doc.save());
    return pages.length;
  }

  /// Render a single page as a PDF byte buffer. Used by the editor's
  /// "Print page" action so the system print dialog can lay it out
  /// without touching the filesystem.
  Future<List<int>> exportSingle({
    required String title,
    required String body,
    Map<String, String> ulidToTitle = const {},
  }) async {
    final doc = pw.Document(title: title, creator: 'Quill');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 48,
          marginBottom: 48,
          marginLeft: 56,
          marginRight: 56,
        ),
        theme: _buildTheme(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xff8a8275),
            ),
          ),
        ),
        build: (ctx) => _buildPage(title, body, ulidToTitle),
      ),
    );
    return doc.save();
  }

  static List<pw.Widget> _buildPage(
    String title,
    String body,
    Map<String, String> ulidToTitle,
  ) {
    final widgets = <pw.Widget>[
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 28,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 18),
    ];
    final lines = body.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        i++;
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(line.substring(4),
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ));
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(line.substring(3),
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ));
        i++;
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
          child: pw.Text(line.substring(2),
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ));
        i++;
        continue;
      }
      if (line.startsWith('```')) {
        final buf = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // closing fence
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xfff0ede6),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            buf.toString(),
            style: pw.TextStyle(
              fontSize: 10,
              font: pw.Font.courier(),
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('> ')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].startsWith('> ')) {
          buf.add(lines[i].substring(2));
          i++;
        }
        widgets.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.fromLTRB(12, 4, 8, 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(
                color: PdfColor.fromInt(0xff8c9f8b),
                width: 2,
              ),
            ),
          ),
          child: pw.Text(_resolveInline(buf.join('\n'), ulidToTitle),
              style: pw.TextStyle(fontSize: 11, lineSpacing: 4)),
        ));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final items = <String>[];
        while (i < lines.length &&
            (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
          items.add(lines[i].substring(2));
          i++;
        }
        widgets.add(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items
              .map((item) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(left: 4, top: 2, bottom: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 4,
                          height: 4,
                          margin: const pw.EdgeInsets.only(top: 5, right: 8),
                          decoration: const pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColor.fromInt(0xff59554b),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _resolveInline(item, ulidToTitle),
                            style:
                                pw.TextStyle(fontSize: 11, lineSpacing: 4),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ));
        continue;
      }
      if (line.trim() == '---') {
        widgets.add(pw.Divider(
          color: PdfColor.fromInt(0xffd8d3c4),
          thickness: 0.5,
          height: 16,
        ));
        i++;
        continue;
      }
      // Paragraph (collect until blank line or block boundary).
      final buf = StringBuffer(line);
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_isBlockStart(lines[i])) {
        buf.write('\n');
        buf.write(lines[i]);
        i++;
      }
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          _resolveInline(buf.toString(), ulidToTitle),
          style: pw.TextStyle(fontSize: 11, lineSpacing: 4),
        ),
      ));
    }
    return widgets;
  }

  static String _resolveInline(String text, Map<String, String> ulidToTitle) {
    var out = text;
    out = out.replaceAllMapped(
      RegExp(r'\[\[([0-9A-Z]{26})\]\]'),
      (m) {
        final ulid = m.group(1)!;
        return ulidToTitle[ulid] ?? ulid;
      },
    );
    // Strip markdown emphasis markers for plain-PDF rendering (we can't
    // easily produce mixed-style runs without RichText-style spans here).
    out = out.replaceAll('**', '');
    out = out.replaceAllMapped(RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'),
        (m) => m.group(1) ?? '');
    out = out.replaceAllMapped(
        RegExp(r'`([^`\n]+)`'), (m) => m.group(1) ?? '');
    return out;
  }

  static bool _isBlockStart(String line) =>
      line.startsWith('```') ||
      line.startsWith('# ') ||
      line.startsWith('## ') ||
      line.startsWith('### ') ||
      line.startsWith('- ') ||
      line.startsWith('* ') ||
      line.startsWith('> ') ||
      line.trim() == '---';

  static pw.ThemeData _buildTheme() {
    return pw.ThemeData(
      defaultTextStyle: pw.TextStyle(
        fontSize: 11,
        color: PdfColor.fromInt(0xff2a2825),
        lineSpacing: 4,
      ),
    );
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
}

class _PageData {
  const _PageData({
    required this.title,
    required this.body,
    required this.relativePath,
  });
  final String title;
  final String body;
  final String relativePath;
}
