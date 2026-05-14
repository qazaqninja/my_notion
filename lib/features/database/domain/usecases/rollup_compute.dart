import '../../../../core/markdown/wikilink_parser.dart';
import '../entities/database_schema.dart';
import '../repositories/database_repository.dart';

/// Computes rollup cell values for every row in [rows] based on the
/// rollup columns declared in [schema]. Returns a fresh list of rows
/// whose `cells` map carries the computed rollup value alongside the
/// original cells.
///
/// A rollup column declares:
///   - `relation:` — the relation column on the SAME row whose ULIDs to follow
///   - `target:`   — the cell key on each related row to aggregate
///   - `agg:`      — sum / avg / min / max / count / list (default sum)
///
/// Unparseable target cells are skipped silently. Missing relations
/// resolve to an empty list, so the rollup becomes 0 (sum/count/avg) /
/// '' (list).
class RollupCompute {
  const RollupCompute._();

  static List<DatabasePageRow> apply(
    List<DatabasePageRow> rows,
    DatabaseSchema schema,
  ) {
    final rollups = [
      for (final c in schema.columns)
        if (c.type == ColumnType.rollup && c.rollupRelation != null) c,
    ];
    if (rollups.isEmpty) return rows;
    final byUlid = {for (final r in rows) r.ulid: r};
    return [
      for (final row in rows)
        row.copyWith(cells: {
          ...row.cells,
          for (final c in rollups)
            c.key: _computeOne(row, c, byUlid),
        }),
    ];
  }

  /// Pure helper exposed for tests — applies a single rollup column to
  /// one row, returning the aggregated value.
  static Object? computeOne(
    DatabasePageRow row,
    ColumnDef column,
    Map<String, DatabasePageRow> byUlid,
  ) =>
      _computeOne(row, column, byUlid);

  static Object? _computeOne(
    DatabasePageRow row,
    ColumnDef column,
    Map<String, DatabasePageRow> byUlid,
  ) {
    final relUlids = _readUlids(row.cells[column.rollupRelation]);
    if (relUlids.isEmpty) {
      return switch (column.rollupAgg) {
        RollupAgg.count => 0,
        RollupAgg.list => '',
        _ => 0,
      };
    }
    final targetKey = column.rollupTarget;
    final values = <Object>[];
    for (final u in relUlids) {
      final r = byUlid[u];
      if (r == null) continue;
      if (targetKey == null) {
        values.add(r.title);
      } else {
        final raw = r.cells[targetKey];
        if (raw == null) continue;
        if (raw is String && raw.isEmpty) continue;
        values.add(raw);
      }
    }
    return _aggregate(values, column.rollupAgg);
  }

  static List<String> _readUlids(dynamic raw) {
    if (raw == null) return const [];
    final out = <String>{};
    if (raw is List) {
      for (final item in raw) {
        out.addAll(WikilinkParser.find('$item').map((w) => w.ulid));
      }
    } else {
      out.addAll(WikilinkParser.find('$raw').map((w) => w.ulid));
    }
    return out.toList();
  }

  static Object _aggregate(List<Object> values, RollupAgg agg) {
    switch (agg) {
      case RollupAgg.count:
        return values.length;
      case RollupAgg.list:
        return values.map((v) => '$v').join(', ');
      case RollupAgg.sum:
      case RollupAgg.avg:
      case RollupAgg.min:
      case RollupAgg.max:
        final nums = <num>[];
        for (final v in values) {
          final n = v is num ? v : num.tryParse('$v'.replaceAll(',', ''));
          if (n != null) nums.add(n);
        }
        if (nums.isEmpty) return 0;
        switch (agg) {
          case RollupAgg.sum:
            return nums.fold<num>(0, (a, b) => a + b);
          case RollupAgg.avg:
            return nums.fold<num>(0, (a, b) => a + b) / nums.length;
          case RollupAgg.min:
            return nums.reduce((a, b) => a < b ? a : b);
          case RollupAgg.max:
            return nums.reduce((a, b) => a > b ? a : b);
          default:
            return 0;
        }
    }
  }
}
