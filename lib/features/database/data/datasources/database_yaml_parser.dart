import 'package:yaml/yaml.dart';

import '../../domain/entities/database_schema.dart';

class DatabaseYamlParser {
  const DatabaseYamlParser._();

  static DatabaseSchema? parse(String yamlText, {required String folderPath}) {
    final dynamic doc = loadYaml(yamlText);
    if (doc is! YamlMap) return null;

    final id = (doc['id'] ?? '').toString();
    final name = (doc['name'] ?? '').toString();
    final iconRaw = doc['icon'];
    final icon = iconRaw != null
        ? iconRaw.toString()
        : (name.isNotEmpty ? name.substring(0, 1) : 'D');
    final color = (doc['color'] ?? '#6B8E7F').toString();

    final columns = <ColumnDef>[];
    final schema = doc['schema'];
    if (schema is YamlMap) {
      for (final entry in schema.entries) {
        final key = '${entry.key}';
        final def = entry.value;
        if (def is YamlMap) {
          columns.add(_parseColumn(key, def));
        }
      }
    }

    final views = <DatabaseView>[];
    final viewsNode = doc['views'];
    if (viewsNode is YamlList) {
      for (final v in viewsNode) {
        if (v is YamlMap) views.add(_parseView(v));
      }
    }

    final rowTemplate = doc['row_template'];
    final locked = doc['locked'] == true ||
        '${doc['locked'] ?? ''}'.trim().toLowerCase() == 'true';
    return DatabaseSchema(
      id: id,
      name: name,
      icon: icon,
      color: color,
      folderPath: folderPath,
      columns: columns,
      views: views.isEmpty
          ? [const DatabaseView(id: 'all', name: 'All', type: ViewType.table)]
          : views,
      rowTemplate: rowTemplate != null ? '$rowTemplate' : null,
      locked: locked,
    );
  }

  static ColumnDef _parseColumn(String key, YamlMap def) {
    final type = _columnType('${def['type'] ?? 'text'}');
    final options = <String>[];
    final opts = def['options'];
    if (opts is YamlList) {
      for (final o in opts) {
        options.add('$o');
      }
    }
    final target = def['target_database'];
    final formula = def['formula'];
    final isParent = def['is_parent'] == true;
    final rollupRelation = def['relation'];
    final rollupTarget = def['target'];
    final rollupAgg = _rollupAgg('${def['agg'] ?? 'sum'}');
    return ColumnDef(
      key: key,
      type: type,
      options: options,
      targetDatabase: target != null ? '$target' : null,
      formula: formula != null ? '$formula' : null,
      isParent: isParent,
      rollupRelation: rollupRelation != null ? '$rollupRelation' : null,
      rollupTarget: rollupTarget != null ? '$rollupTarget' : null,
      rollupAgg: rollupAgg,
    );
  }

  static RollupAgg _rollupAgg(String s) => switch (s.toLowerCase()) {
        'avg' || 'mean' || 'average' => RollupAgg.avg,
        'min' => RollupAgg.min,
        'max' => RollupAgg.max,
        'count' => RollupAgg.count,
        'list' || 'join' => RollupAgg.list,
        _ => RollupAgg.sum,
      };

  static DatabaseView _parseView(YamlMap m) {
    List<String>? visible;
    final v = m['visible'];
    if (v is YamlList) {
      visible = [for (final k in v) '$k'];
    }
    List<String>? cardFields;
    final cf = m['card_fields'];
    if (cf is YamlList) {
      cardFields = [for (final k in cf) '$k'];
    }
    return DatabaseView(
      id: '${m['id'] ?? m['name'] ?? 'view'}',
      name: '${m['name'] ?? 'View'}',
      type: _viewType('${m['type'] ?? 'table'}'),
      groupBy: m['group_by'] != null ? '${m['group_by']}' : null,
      visible: visible,
      cardFields: cardFields,
    );
  }

  static ColumnType _columnType(String s) => switch (s) {
        'number' => ColumnType.number,
        'date' => ColumnType.date,
        'select' => ColumnType.select,
        'multi' => ColumnType.multi,
        'multi_select' => ColumnType.multi,
        'relation' => ColumnType.relation,
        'formula' => ColumnType.formula,
        'checkbox' => ColumnType.checkbox,
        'file' => ColumnType.file,
        'rollup' => ColumnType.rollup,
        'created_time' || 'created' => ColumnType.createdTime,
        'last_edited_time' || 'edited_time' || 'modified' => ColumnType.lastEditedTime,
        _ => ColumnType.text,
      };

  static ViewType _viewType(String s) => switch (s) {
        'gallery' => ViewType.gallery,
        'board' => ViewType.board,
        'timeline' => ViewType.timeline,
        'calendar' => ViewType.calendar,
        'chart' => ViewType.chart,
        'list' => ViewType.list,
        _ => ViewType.table,
      };
}
