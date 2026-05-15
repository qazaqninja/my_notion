import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/ulid/ulid_generator.dart';

/// Tailored Asana CSV import — produces a database whose `.database.yaml`
/// recognises Asana's column conventions (Name, Section/Column, Tags,
/// Due Date, Assignee, Notes). Cells from the `Notes` column flow into
/// each row's body; everything else stays in frontmatter.
///
/// Falls back to a plain-CSV behaviour for unknown columns: each is
/// emitted as a text column.
class AsanaCsvImporter {
  const AsanaCsvImporter._();

  static const _ulids = UlidGenerator();

  static Future<AsanaImportSummary> importTo(
    File source,
    Directory vaultRoot,
  ) async {
    final raw = await source.readAsString();
    final rows = _parseCsv(raw);
    if (rows.length < 2) {
      throw const FormatException('CSV must have a header row + ≥1 data row');
    }
    final header = rows.first.map((s) => s.trim()).toList();
    final dataRows = rows.skip(1).toList();

    final mapping = _classify(header, dataRows);
    final folderName = _safeFolderName(p.basenameWithoutExtension(source.path));
    final folder = Directory(p.join(vaultRoot.path, folderName));
    await folder.create(recursive: true);

    final imported = p.basename(source.path);
    final dbId = _ulids.generate();
    final schemaYaml = _renderSchema(
      dbId: dbId,
      name: folderName,
      mapping: mapping,
    );
    await File(p.join(folder.path, '.database.yaml'))
        .writeAsString(schemaYaml);

    final usedNames = <String>{};
    final written = <ImportedAsanaTask>[];
    for (final row in dataRows) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      final title = mapping.titleIdx < row.length
          ? row[mapping.titleIdx].trim()
          : '';
      if (title.isEmpty) continue;
      try {
        final ulid = _ulids.generate();
        final safe = _uniqueFilename(usedNames, _safeFileName(title));
        final rel = p.join(folderName, '$safe.md');
        final out = File(p.join(vaultRoot.path, rel));
        final body = mapping.notesIdx != null && mapping.notesIdx! < row.length
            ? row[mapping.notesIdx!]
            : '';
        final fmBuf = StringBuffer('---\n');
        fmBuf.writeln('id: $ulid');
        fmBuf.writeln('title: ${yamlSafeScalar(title)}');
        for (var i = 0; i < header.length; i++) {
          if (i == mapping.titleIdx || i == mapping.notesIdx) continue;
          if (i >= row.length) continue;
          final v = row[i].trim();
          if (v.isEmpty) continue;
          final key = _yamlKey(mapping.keyForIndex(i));
          if (mapping.multiIdx.contains(i)) {
            final parts = _splitMulti(v);
            // Quote each list element so commas / colons / brackets in
            // a tag don't split the flow list (mirrors M689).
            fmBuf.writeln(
                '$key: [${parts.map(yamlFlowItem).join(', ')}]');
          } else {
            fmBuf.writeln('$key: ${yamlSafeScalar(v)}');
          }
        }
        fmBuf.writeln('imported_from: ${yamlSafeScalar(imported)}');
        fmBuf.writeln('---');
        fmBuf.writeln();
        await out.writeAsString('${fmBuf.toString()}${body.trim()}\n');
        written.add(ImportedAsanaTask(
          ulid: ulid,
          relativePath: rel,
          title: title,
        ));
      } catch (e, st) {
        // Per-task robustness (M731-M734).
        // ignore: avoid_print
        print('asana_importer: skipping task "$title" — $e\n$st');
      }
    }
    return AsanaImportSummary(folder: folderName, tasks: written);
  }

  // ---------------------------------------------------------------- classify

  static _Mapping _classify(List<String> header, List<List<String>> rows) {
    int titleIdx = 0;
    int? notesIdx;
    int? sectionIdx;
    final multiIdx = <int>{};
    final sectionOptions = <String>{};
    for (var i = 0; i < header.length; i++) {
      final h = header[i].trim().toLowerCase();
      if (h == 'name' || h == 'title' || h == 'task') {
        titleIdx = i;
      } else if (h == 'notes' || h == 'description') {
        notesIdx = i;
      } else if (h == 'section/column' ||
          h == 'section' ||
          h == 'status' ||
          h == 'column') {
        sectionIdx = i;
      } else if (h == 'tags' || h == 'labels') {
        multiIdx.add(i);
      }
    }
    if (sectionIdx != null) {
      for (final r in rows) {
        if (sectionIdx < r.length) {
          final v = r[sectionIdx].trim();
          if (v.isNotEmpty) sectionOptions.add(v);
        }
      }
    }
    return _Mapping(
      titleIdx: titleIdx,
      notesIdx: notesIdx,
      sectionIdx: sectionIdx,
      sectionOptions: sectionOptions.toList()..sort(),
      multiIdx: multiIdx,
      header: header,
    );
  }

  // ----------------------------------------------------------------- schema

  static String _renderSchema({
    required String dbId,
    required String name,
    required _Mapping mapping,
  }) {
    final buf = StringBuffer();
    buf.writeln('id: $dbId');
    buf.writeln('name: ${yamlSafeScalar(name)}');
    buf.writeln('icon: A');
    buf.writeln('color: "#B46F4F"');
    buf.writeln('schema:');
    buf.writeln('  title:');
    buf.writeln('    type: text');
    for (var i = 0; i < mapping.header.length; i++) {
      if (i == mapping.titleIdx || i == mapping.notesIdx) continue;
      final key = mapping.keyForIndex(i);
      buf.writeln('  ${_yamlKey(key)}:');
      if (i == mapping.sectionIdx) {
        buf.writeln('    type: select');
        if (mapping.sectionOptions.isNotEmpty) {
          buf.writeln('    options:');
          for (final o in mapping.sectionOptions) {
            buf.writeln('      - ${yamlSafeScalar(o)}');
          }
        }
      } else if (mapping.multiIdx.contains(i)) {
        buf.writeln('    type: multi');
      } else if (key == 'due_date' ||
          key == 'start_date' ||
          key == 'completed_at' ||
          key == 'created_at') {
        buf.writeln('    type: date');
      } else {
        buf.writeln('    type: text');
      }
    }
    buf.writeln('views:');
    buf.writeln('  - id: all');
    buf.writeln('    name: All tasks');
    buf.writeln('    type: table');
    if (mapping.sectionIdx != null) {
      buf.writeln('  - id: kanban');
      buf.writeln('    name: Kanban');
      buf.writeln('    type: board');
      buf.writeln(
          '    group_by: ${mapping.keyForIndex(mapping.sectionIdx!)}');
    }
    return buf.toString();
  }

  // ----------------------------------------------------------------- helpers

  static List<String> _splitMulti(String s) {
    final parts = s
        .split(RegExp(r'[,;|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts;
  }

  static String _safeFolderName(String name) {
    var s = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Asana import';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Task';
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

  static String _yamlKey(String k) {
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(k)) return k;
    return '"${k.replaceAll('"', r'\"')}"';
  }

  // ------------------------------------------------------------------ csv

  /// Minimal RFC-4180-ish CSV parser. Handles double-quoted fields with
  /// `""` escapes and inline newlines.
  static List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    final row = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < raw.length && raw[i + 1] == '"') {
            buf.write('"');
            i += 1;
          } else {
            quoted = false;
          }
        } else {
          buf.write(c);
        }
      } else {
        if (c == '"') {
          quoted = true;
        } else if (c == ',') {
          row.add(buf.toString());
          buf.clear();
        } else if (c == '\n') {
          row.add(buf.toString());
          buf.clear();
          rows.add(List<String>.from(row));
          row.clear();
        } else if (c == '\r') {
          // Swallow.
        } else {
          buf.write(c);
        }
      }
    }
    if (buf.isNotEmpty || row.isNotEmpty) {
      row.add(buf.toString());
      rows.add(row);
    }
    return rows;
  }
}

class _Mapping {
  const _Mapping({
    required this.titleIdx,
    required this.notesIdx,
    required this.sectionIdx,
    required this.sectionOptions,
    required this.multiIdx,
    required this.header,
  });
  final int titleIdx;
  final int? notesIdx;
  final int? sectionIdx;
  final List<String> sectionOptions;
  final Set<int> multiIdx;
  final List<String> header;

  /// Frontmatter key for header column [i]. Normalises Asana's
  /// PascalCase / space-separated labels to snake_case.
  String keyForIndex(int i) {
    if (i == sectionIdx) return 'status';
    final raw = header[i].trim().toLowerCase();
    return raw.replaceAll(RegExp(r'\s+'), '_').replaceAll('/', '_');
  }
}

class ImportedAsanaTask {
  const ImportedAsanaTask({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}

class AsanaImportSummary {
  const AsanaImportSummary({required this.folder, required this.tasks});
  final String folder;
  final List<ImportedAsanaTask> tasks;
}
