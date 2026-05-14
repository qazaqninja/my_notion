enum ColumnType { text, number, date, select, multi, relation, formula, checkbox, file }

class ColumnDef {
  const ColumnDef({
    required this.key,
    required this.type,
    this.options = const [],
    this.targetDatabase,
    this.formula,
  });

  final String key;
  final ColumnType type;
  final List<String> options;
  final String? targetDatabase;

  /// For [ColumnType.formula]: the source expression to evaluate per row.
  /// Read from `.database.yaml`'s `schema.<key>.formula:` field.
  final String? formula;
}

enum ViewType { table, gallery, board, timeline, calendar, chart }

class DatabaseView {
  const DatabaseView({
    required this.id,
    required this.name,
    required this.type,
    this.groupBy,
  });

  final String id;
  final String name;
  final ViewType type;
  final String? groupBy;
}

class DatabaseSchema {
  const DatabaseSchema({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.folderPath,
    required this.columns,
    required this.views,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final String folderPath;
  final List<ColumnDef> columns;
  final List<DatabaseView> views;

  DatabaseView? viewById(String? id) {
    if (id == null) return views.isEmpty ? null : views.first;
    for (final v in views) {
      if (v.id == id) return v;
    }
    return views.isEmpty ? null : views.first;
  }
}
