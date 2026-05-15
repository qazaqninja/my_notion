import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/text/strip_bom.dart';
import '../../../core/ulid/ulid_generator.dart';
import 'html_to_markdown.dart';

/// Evernote .enex (Export Notebook) import.
///
/// An .enex file is XML wrapping a list of `<note>` elements; each note
/// carries `<title>`, `<content>` (XHTML, usually CDATA-wrapped), zero
/// or more `<tag>` entries, and `<created>` / `<updated>` ISO-ish dates.
///
/// We dependency-free regex-parse the structure (the M175 path already
/// handles XHTML once we've stripped the `<en-note>` wrapper), and emit
/// one .md per note under `<vault>/Evernote/<safe-title>.md`.
class EnexPageImporter {
  const EnexPageImporter._();

  static const _ulids = UlidGenerator();

  static Future<EnexImportSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Evernote',
  }) async {
    final raw = stripBom(await source.readAsString());
    final notes = _parseNotes(raw);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final imported = p.basename(source.path);
    final usedNames = <String>{};
    final written = <ImportedEnexNote>[];
    for (final note in notes) {
      try {
        final ulid = _ulids.generate();
        final safe = _uniqueFilename(usedNames, _safeFileName(note.title));
        final rel = p.join(targetFolder, '$safe.md');
        final out = File(p.join(vaultRoot.path, rel));
        final body = HtmlToMarkdown.convert(note.content);
        final fmBuf = StringBuffer('---\n');
        fmBuf.writeln('id: $ulid');
        fmBuf.writeln('title: ${yamlSafeScalar(note.title)}');
        if (note.tags.isNotEmpty) {
          // Per-tag quoting so an Evernote tag containing ',' / ':' /
          // '[' / ']' doesn't break the flow list (mirrors M689).
          fmBuf.writeln(
              'tags: [${note.tags.map(yamlFlowItem).join(', ')}]');
        }
        if (note.created != null) {
          fmBuf.writeln('created_at: ${note.created}');
        }
        if (note.updated != null) {
          fmBuf.writeln('updated: ${note.updated}');
        }
        fmBuf.writeln('imported_from: ${yamlSafeScalar(imported)}');
        fmBuf.writeln('---');
        fmBuf.writeln();
        await out.writeAsString('${fmBuf.toString()}${body.trim()}\n');
        written.add(ImportedEnexNote(
          ulid: ulid,
          relativePath: rel,
          title: note.title,
        ));
      } catch (e, st) {
        // Skip a single failing note (encoding, disk write) rather
        // than aborting the whole notebook import — matches M731's
        // csv_importer robustness.
        // ignore: avoid_print
        print('enex_importer: skipping note "${note.title}" — $e\n$st');
      }
    }
    return EnexImportSummary(folder: targetFolder, notes: written);
  }

  // ----------------------------------------------------------- parsing

  static List<EnexNote> _parseNotes(String raw) {
    final out = <EnexNote>[];
    final noteRe = RegExp(r'<note>([\s\S]*?)</note>', caseSensitive: false);
    for (final m in noteRe.allMatches(raw)) {
      final inner = m.group(1) ?? '';
      final title = _readTag(inner, 'title') ?? 'Untitled note';
      final created = _readTag(inner, 'created');
      final updated = _readTag(inner, 'updated');
      final content = _readCdataOrTag(inner, 'content') ?? '';
      final tags = <String>[];
      for (final t
          in RegExp(r'<tag>([\s\S]*?)</tag>', caseSensitive: false)
              .allMatches(inner)) {
        final v = _decode(t.group(1) ?? '').trim();
        if (v.isNotEmpty) tags.add(v);
      }
      out.add(EnexNote(
        title: _decode(title).trim(),
        content: _stripEnNoteWrapper(content),
        tags: tags,
        created: _formatDate(created),
        updated: _formatDate(updated),
      ));
    }
    return out;
  }

  static String? _readTag(String src, String name) {
    final m =
        RegExp('<$name>([\\s\\S]*?)</$name>', caseSensitive: false)
            .firstMatch(src);
    return m?.group(1);
  }

  static String? _readCdataOrTag(String src, String name) {
    final tag =
        RegExp('<$name>([\\s\\S]*?)</$name>', caseSensitive: false)
            .firstMatch(src);
    if (tag == null) return null;
    var inner = tag.group(1) ?? '';
    final cdata =
        RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>').firstMatch(inner);
    if (cdata != null) inner = cdata.group(1) ?? '';
    return inner;
  }

  /// Evernote wraps content in `<en-note>...</en-note>`. Drop the wrapper
  /// so HtmlToMarkdown sees just the inner XHTML.
  static String _stripEnNoteWrapper(String s) {
    final m = RegExp(
            r'<en-note\b[^>]*>([\s\S]*?)</en-note>',
            caseSensitive: false)
        .firstMatch(s);
    return m?.group(1) ?? s;
  }

  /// `<created>20250607T123456Z</created>` → `2025-06-07`.
  /// Returns null for missing or malformed input.
  static String? _formatDate(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(raw.trim());
    if (m == null) return null;
    return '${m.group(1)}-${m.group(2)}-${m.group(3)}';
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

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Untitled note';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

  static String _uniqueFilename(Set<String> used, String base) {
    if (!used.contains(base)) {
      used.add(base);
      return base;
    }
    var n = 2;
    while (used.contains('$base ($n)')) {
      n += 1;
    }
    final out = '$base ($n)';
    used.add(out);
    return out;
  }

}

class EnexNote {
  const EnexNote({
    required this.title,
    required this.content,
    required this.tags,
    this.created,
    this.updated,
  });
  final String title;
  final String content;
  final List<String> tags;
  final String? created;
  final String? updated;
}

class ImportedEnexNote {
  const ImportedEnexNote({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}

class EnexImportSummary {
  const EnexImportSummary({required this.folder, required this.notes});
  final String folder;
  final List<ImportedEnexNote> notes;
}
