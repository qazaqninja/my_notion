import 'dart:io';

import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Writes a CSV row per [DatabasePageRow] using the schema's columns as
/// headers (with `title` always first). RFC 4180-style quoting: any cell
/// containing `,` `"` or a newline is double-quoted, and embedded `"` are
/// doubled.
class CsvExporter {
  const CsvExporter();

  Future<int> export({
    required File destination,
    required DatabaseSchema schema,
    required List<DatabasePageRow> rows,
  }) async {
    final columns = _columnOrder(schema);
    final buf = StringBuffer();
    buf.writeln(columns.map(_escape).join(','));
    for (final row in rows) {
      final values = <String>[];
      for (final col in columns) {
        if (col == 'title') {
          values.add(_escape(row.title));
        } else {
          values.add(_escape('${row.cells[col] ?? ''}'));
        }
      }
      buf.writeln(values.join(','));
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsString(buf.toString());
    return rows.length;
  }

  static List<String> _columnOrder(DatabaseSchema schema) {
    final out = <String>['title'];
    for (final c in schema.columns) {
      if (c.key == 'title' || c.key == 'id') continue;
      out.add(c.key);
    }
    return out;
  }

  static String _escape(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
