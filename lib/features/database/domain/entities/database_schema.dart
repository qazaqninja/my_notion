enum ColumnType {
  text,
  number,
  date,
  select,
  multi,
  relation,
  formula,
  checkbox,
  file,
  createdTime,
  lastEditedTime,
}

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
    this.visible,
  });

  final String id;
  final String name;
  final ViewType type;
  final String? groupBy;

  /// When non-null, only these column keys are rendered in this view.
  /// Title is always shown regardless (it's the page identifier).
  /// Read from `.database.yaml`'s `views[].visible: [...]` list.
  final List<String>? visible;
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

  /// Returns a new DatabaseSchema with [columns] reduced to those in [keys].
  /// Title is always preserved (it's the page identifier). Used by view
  /// rendering to honour `views[].visible:` lists.
  DatabaseSchema filterColumns(Set<String>? keys) {
    if (keys == null) return this;
    final allowed = {...keys, 'title'};
    return DatabaseSchema(
      id: id,
      name: name,
      icon: icon,
      color: color,
      folderPath: folderPath,
      views: views,
      columns: [
        for (final c in columns)
          if (allowed.contains(c.key)) c,
      ],
    );
  }
}
