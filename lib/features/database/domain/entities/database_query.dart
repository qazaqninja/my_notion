import 'database_schema.dart';

enum FilterOp {
  equals,
  notEquals,
  contains,
  isEmpty,
  isNotEmpty,
  gt,
  lt,
  gte,
  lte,
}

class FilterRule {
  const FilterRule({
    required this.columnKey,
    required this.op,
    this.value,
  });

  final String columnKey;
  final FilterOp op;
  final String? value;

  bool needsValue() {
    switch (op) {
      case FilterOp.isEmpty:
      case FilterOp.isNotEmpty:
        return false;
      default:
        return true;
    }
  }
}

class SortRule {
  const SortRule({required this.columnKey, this.ascending = true});
  final String columnKey;
  final bool ascending;
}

/// Aggregated query state for a table view: filters → sorts → groupBy.
class DatabaseQuery {
  const DatabaseQuery({
    this.filters = const [],
    this.sorts = const [],
    this.groupBy,
    this.subGroupBy,
  });

  final List<FilterRule> filters;
  final List<SortRule> sorts;
  final String? groupBy;

  /// Optional 2nd-level grouping. Honoured by BoardView (renders
  /// section dividers within each column) and ApplyQuery.group2.
  final String? subGroupBy;

  DatabaseQuery copyWith({
    List<FilterRule>? filters,
    List<SortRule>? sorts,
    Object? groupBy = _sentinel,
    Object? subGroupBy = _sentinel,
  }) {
    return DatabaseQuery(
      filters: filters ?? this.filters,
      sorts: sorts ?? this.sorts,
      groupBy: identical(groupBy, _sentinel)
          ? this.groupBy
          : groupBy as String?,
      subGroupBy: identical(subGroupBy, _sentinel)
          ? this.subGroupBy
          : subGroupBy as String?,
    );
  }

  static const _sentinel = Object();
}

/// Operators that are meaningful for a given column type. Used by the
/// filter dropdown to populate its operator list.
List<FilterOp> filterOpsForType(ColumnType t) {
  switch (t) {
    case ColumnType.number:
      return const [
        FilterOp.equals,
        FilterOp.notEquals,
        FilterOp.gt,
        FilterOp.lt,
        FilterOp.gte,
        FilterOp.lte,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ];
    case ColumnType.date:
    case ColumnType.createdTime:
    case ColumnType.lastEditedTime:
      return const [
        FilterOp.equals,
        FilterOp.notEquals,
        FilterOp.gt,
        FilterOp.lt,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ];
    case ColumnType.checkbox:
      return const [FilterOp.equals];
    case ColumnType.select:
    case ColumnType.relation:
      return const [
        FilterOp.equals,
        FilterOp.notEquals,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ];
    case ColumnType.text:
    case ColumnType.multi:
    case ColumnType.formula:
    case ColumnType.file:
      return const [
        FilterOp.contains,
        FilterOp.equals,
        FilterOp.notEquals,
        FilterOp.isEmpty,
        FilterOp.isNotEmpty,
      ];
  }
}

String filterOpLabel(FilterOp op) => switch (op) {
      FilterOp.equals => 'equals',
      FilterOp.notEquals => '≠',
      FilterOp.contains => 'contains',
      FilterOp.isEmpty => 'is empty',
      FilterOp.isNotEmpty => 'is not empty',
      FilterOp.gt => '>',
      FilterOp.lt => '<',
      FilterOp.gte => '≥',
      FilterOp.lte => '≤',
    };
