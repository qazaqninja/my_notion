import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/markdown/frontmatter_parser.dart';
import '../../../../core/markdown/type_inference.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/entities/page.dart';
import '../../domain/entities/database_schema.dart';

/// Imports a CSV file into a new vault database. Creates a folder
/// `<vaultRoot>/<csvBasename>/`, drops a `.database.yaml` describing the
/// columns, and writes one `<row-title>.md` per data row.
///
/// Type inference: a column is `number` if all non-empty cells parse as
/// num, `date` if all parse as YYYY-MM-DD, `checkbox` if all are
/// true/false (case-insensitive), otherwise `text`.
///
/// Column #0 in the CSV becomes the page title — if a column literally
/// named "title" or "name" exists, it's picked instead.
class CsvImporter {
  const CsvImporter({this.ulids = const UlidGenerator()});

  final UlidGenerator ulids;

  /// Performs the import. Returns a summary the UI can show.
  Future<CsvImportResult> importTo(
    File csv,
    Directory vaultRoot, {
    String? folderName,
  }) async {
    final raw = await csv.readAsString();
    final rows = _parse(raw);
    if (rows.length < 2) {
      throw const FormatException('CSV must have a header row + ≥1 data row');
    }
    final header = rows.first;
    final dataRows = rows.skip(1).toList();

    final titleIdx = _pickTitleColumn(header);
    final columns = _inferColumns(header, dataRows);

    final base = folderName ?? p.basenameWithoutExtension(csv.path);
    final safeFolder = base
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final folder = Directory(p.join(vaultRoot.path, safeFolder.isEmpty ? 'Imported' : safeFolder));
    await folder.create(recursive: true);

    // Write .database.yaml.
    final dbId = ulids.generate();
    final yamlBuf = StringBuffer();
    yamlBuf.writeln('id: $dbId');
    yamlBuf.writeln('name: ${safeFolder.isEmpty ? 'Imported' : safeFolder}');
    yamlBuf.writeln('icon: 📑');
    yamlBuf.writeln('color: "#6B8E7F"');
    yamlBuf.writeln('schema:');
    for (final c in columns) {
      yamlBuf.writeln('  ${_yamlKey(c.key)}:');
      yamlBuf.writeln('    type: ${_columnTypeName(c.type)}');
    }
    await File(p.join(folder.path, '.database.yaml'))
        .writeAsString(yamlBuf.toString());

    // Write one .md per row.
    int written = 0;
    final usedNames = <String>{};
    for (final row in dataRows) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      final title = (titleIdx < row.length ? row[titleIdx] : '').trim();
      final pageUlid = ulids.generate();
      final safeName = _uniqueFilename(
        usedNames,
        title.isEmpty ? pageUlid : title,
      );
      final entries = <FrontmatterEntry>[
        FrontmatterEntry(
          key: 'id',
          rawScalar: pageUlid,
          type: FrontmatterType.ulid,
          value: pageUlid,
        ),
        if (title.isNotEmpty)
          FrontmatterEntry(
            key: 'title',
            rawScalar: title,
            type: FrontmatterType.text,
            value: title,
          ),
        for (int i = 0; i < columns.length; i++)
          if (i < row.length && row[i].trim().isNotEmpty && i != titleIdx)
            _entryFor(columns[i], row[i]),
      ];
      final page = ParsedMarkdown(
        frontmatter: Frontmatter(entries: entries),
        body: '',
      );
      final raw = FrontmatterParser.serialise(page);
      await File(p.join(folder.path, '$safeName.md')).writeAsString(raw);
      written++;
    }

    return CsvImportResult(
      folderPath: folder.path,
      rowsWritten: written,
      columns: columns.length,
    );
  }

  // ── helpers ──

  static String _uniqueFilename(Set<String> used, String name) {
    final safe = name
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var candidate = safe.isEmpty ? 'Untitled' : safe;
    var i = 2;
    while (used.contains(candidate)) {
      candidate = '$safe-$i';
      i++;
    }
    used.add(candidate);
    return candidate;
  }

  static String _yamlKey(String k) {
    // YAML allows bare keys for simple identifiers; quote otherwise.
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(k)) return k;
    return '"${k.replaceAll('"', r'\"')}"';
  }

  FrontmatterEntry _entryFor(ColumnDef c, String raw) {
    final v = raw.trim();
    switch (c.type) {
      case ColumnType.number:
        return FrontmatterEntry(
          key: c.key,
          rawScalar: v,
          type: FrontmatterType.number,
          value: num.tryParse(v) ?? v,
        );
      case ColumnType.checkbox:
        final b = v.toLowerCase() == 'true';
        return FrontmatterEntry(
          key: c.key,
          rawScalar: b ? 'true' : 'false',
          type: FrontmatterType.checkbox,
          value: b,
        );
      case ColumnType.date:
        return FrontmatterEntry(
          key: c.key,
          rawScalar: v,
          type: FrontmatterType.date,
          value: v,
        );
      case ColumnType.text:
      case ColumnType.select:
      case ColumnType.multi:
      case ColumnType.relation:
      case ColumnType.formula:
      case ColumnType.rollup:
      case ColumnType.person:
      case ColumnType.file:
      case ColumnType.createdTime:
      case ColumnType.lastEditedTime:
        return FrontmatterEntry(
          key: c.key,
          rawScalar: v,
          type: FrontmatterType.text,
          value: v,
        );
    }
  }

  static int _pickTitleColumn(List<String> header) {
    for (var i = 0; i < header.length; i++) {
      final k = header[i].trim().toLowerCase();
      if (k == 'title' || k == 'name') return i;
    }
    return 0;
  }

  /// Infer column type for each header by looking at all data rows.
  static List<ColumnDef> _inferColumns(
    List<String> header,
    List<List<String>> data,
  ) {
    final out = <ColumnDef>[];
    for (var col = 0; col < header.length; col++) {
      final values = <String>[];
      for (final row in data) {
        if (col < row.length && row[col].trim().isNotEmpty) {
          values.add(row[col].trim());
        }
      }
      ColumnType type;
      if (values.isEmpty) {
        type = ColumnType.text;
      } else if (values.every((v) => num.tryParse(v) != null)) {
        type = ColumnType.number;
      } else if (values.every(TypeInference.isDate)) {
        type = ColumnType.date;
      } else if (values.every(
          (v) => v.toLowerCase() == 'true' || v.toLowerCase() == 'false')) {
        type = ColumnType.checkbox;
      } else {
        type = ColumnType.text;
      }
      out.add(ColumnDef(key: header[col].trim(), type: type));
    }
    return out;
  }

  /// Parses a CSV string per RFC 4180-ish rules: quoted fields, doubled
  /// quotes for embedded quotes, comma separator, CRLF or LF row sep.
  static List<List<String>> _parse(String raw) {
    final rows = <List<String>>[];
    var row = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < raw.length) {
      final ch = raw[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < raw.length && raw[i + 1] == '"') {
            buf.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        buf.write(ch);
        i++;
      } else {
        if (ch == '"') {
          inQuotes = true;
          i++;
        } else if (ch == ',') {
          row.add(buf.toString());
          buf.clear();
          i++;
        } else if (ch == '\n' || ch == '\r') {
          row.add(buf.toString());
          buf.clear();
          rows.add(row);
          row = [];
          if (ch == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') {
            i += 2;
          } else {
            i++;
          }
        } else {
          buf.write(ch);
          i++;
        }
      }
    }
    if (buf.isNotEmpty || row.isNotEmpty) {
      row.add(buf.toString());
      rows.add(row);
    }
    return rows;
  }

  static String _columnTypeName(ColumnType t) => switch (t) {
        ColumnType.number => 'number',
        ColumnType.date => 'date',
        ColumnType.select => 'select',
        ColumnType.multi => 'multi',
        ColumnType.relation => 'relation',
        ColumnType.formula => 'formula',
        ColumnType.rollup => 'rollup',
        ColumnType.person => 'person',
        ColumnType.checkbox => 'checkbox',
        ColumnType.file => 'file',
        ColumnType.createdTime => 'created_time',
        ColumnType.lastEditedTime => 'last_edited_time',
        ColumnType.text => 'text',
      };
}

class CsvImportResult {
  const CsvImportResult({
    required this.folderPath,
    required this.rowsWritten,
    required this.columns,
  });
  final String folderPath;
  final int rowsWritten;
  final int columns;
}
