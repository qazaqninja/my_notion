import '../entities/database_query.dart';
import '../entities/database_schema.dart';
import '../repositories/database_repository.dart';

/// Pure functions that apply a [DatabaseQuery] to an in-memory list of rows.
/// All comparisons use the raw cell string representations to stay decoupled
/// from frontmatter typing — we coerce on demand.
class ApplyQuery {
  const ApplyQuery._();

  /// Filter + sort. Group is handled separately because callers may want
  /// to group AFTER sorting within each group.
  static List<DatabasePageRow> apply(
    Iterable<DatabasePageRow> rows,
    DatabaseQuery query,
    DatabaseSchema schema,
  ) {
    var out = rows.where((row) => _matchesAll(row, query.filters, schema)).toList();
    if (query.sorts.isNotEmpty) {
      out.sort((a, b) {
        for (final s in query.sorts) {
          final av = a.cells[s.columnKey];
          final bv = b.cells[s.columnKey];
          final emptyA = _isEmpty(av);
          final emptyB = _isEmpty(bv);
          // Empties always sort last regardless of direction.
          if (emptyA && emptyB) continue;
          if (emptyA) return 1;
          if (emptyB) return -1;
          final col = _column(schema, s.columnKey);
          final cmp = _compareNonEmpty(av, bv, col);
          if (cmp != 0) return s.ascending ? cmp : -cmp;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    return out;
  }

  /// Group an already-filtered/sorted list by [groupBy]. Empty groups still
  /// appear if [schema] declares the column's select options.
  static Map<String, List<DatabasePageRow>> group(
    List<DatabasePageRow> rows,
    String? groupBy,
    DatabaseSchema schema,
  ) {
    if (groupBy == null) return {'All': rows};
    final col = _column(schema, groupBy);
    final out = <String, List<DatabasePageRow>>{};
    if (col?.options.isNotEmpty ?? false) {
      for (final option in col!.options) {
        out[option] = [];
      }
    }
    for (final row in rows) {
      final raw = '${row.cells[groupBy] ?? ''}';
      final key = raw.trim().isEmpty ? '—' : raw;
      out.putIfAbsent(key, () => []).add(row);
    }
    // Drop empty pre-seeded groups when there are no matching rows AND the
    // user has active filters (otherwise they'd see ghost columns).
    return out;
  }

  static bool _matchesAll(
    DatabasePageRow row,
    List<FilterRule> filters,
    DatabaseSchema schema,
  ) {
    for (final f in filters) {
      if (!_matches(row, f, schema)) return false;
    }
    return true;
  }

  static bool _matches(
    DatabasePageRow row,
    FilterRule rule,
    DatabaseSchema schema,
  ) {
    final raw = row.cells[rule.columnKey];
    final col = _column(schema, rule.columnKey);
    switch (rule.op) {
      case FilterOp.isEmpty:
        return _isEmpty(raw);
      case FilterOp.isNotEmpty:
        return !_isEmpty(raw);
      case FilterOp.equals:
        return _eq(raw, rule.value, col);
      case FilterOp.notEquals:
        return !_eq(raw, rule.value, col);
      case FilterOp.contains:
        return '${raw ?? ''}'.toLowerCase().contains(
              (rule.value ?? '').toLowerCase(),
            );
      case FilterOp.gt:
      case FilterOp.lt:
      case FilterOp.gte:
      case FilterOp.lte:
        return _numCmp(raw, rule.value, rule.op, col);
    }
  }

  static bool _isEmpty(Object? raw) {
    if (raw == null) return true;
    if (raw is String) return raw.trim().isEmpty;
    if (raw is List) return raw.isEmpty;
    return false;
  }

  static bool _eq(Object? raw, String? expected, ColumnDef? col) {
    if (expected == null) return _isEmpty(raw);
    if (col?.type == ColumnType.checkbox) {
      final a = '${raw ?? ''}'.toLowerCase() == 'true';
      final b = expected.toLowerCase() == 'true';
      return a == b;
    }
    if (col?.type == ColumnType.number) {
      final a = num.tryParse('${raw ?? ''}');
      final b = num.tryParse(expected);
      if (a != null && b != null) return a == b;
    }
    return '${raw ?? ''}'.toLowerCase().trim() ==
        expected.toLowerCase().trim();
  }

  static bool _numCmp(Object? raw, String? value, FilterOp op, ColumnDef? col) {
    if (col?.type == ColumnType.date) {
      // Use lexicographic comparison for YYYY-MM-DD strings (works since
      // they're zero-padded and same length).
      final a = '${raw ?? ''}'.trim();
      final b = (value ?? '').trim();
      if (a.isEmpty || b.isEmpty) return false;
      final cmp = a.compareTo(b);
      return _opMatches(cmp, op);
    }
    final a = num.tryParse('${raw ?? ''}');
    final b = num.tryParse(value ?? '');
    if (a == null || b == null) return false;
    return _opMatches(a.compareTo(b), op);
  }

  static bool _opMatches(int cmp, FilterOp op) => switch (op) {
        FilterOp.gt => cmp > 0,
        FilterOp.lt => cmp < 0,
        FilterOp.gte => cmp >= 0,
        FilterOp.lte => cmp <= 0,
        _ => false,
      };

  static int _compareNonEmpty(Object? a, Object? b, ColumnDef? col) {
    if (col?.type == ColumnType.number) {
      final na = num.tryParse('$a');
      final nb = num.tryParse('$b');
      if (na != null && nb != null) return na.compareTo(nb);
    }
    if (col?.type == ColumnType.checkbox) {
      final ba = '$a'.toLowerCase() == 'true';
      final bb = '$b'.toLowerCase() == 'true';
      return ba == bb ? 0 : (ba ? -1 : 1);
    }
    return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
  }

  static ColumnDef? _column(DatabaseSchema schema, String key) {
    for (final c in schema.columns) {
      if (c.key == key) return c;
    }
    return null;
  }
}
