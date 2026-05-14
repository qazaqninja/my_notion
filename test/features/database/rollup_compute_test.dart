import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/domain/usecases/rollup_compute.dart';

const _subA = DatabasePageRow(
  ulid: 'AAAAAAAAAAAAAAAAAAAAAAAAA0',
  title: 'Sub A',
  relativePath: 'Sub/A.md',
  cells: {'estimate': '3'},
);
const _subB = DatabasePageRow(
  ulid: 'BBBBBBBBBBBBBBBBBBBBBBBBB0',
  title: 'Sub B',
  relativePath: 'Sub/B.md',
  cells: {'estimate': '5'},
);

DatabaseSchema _schemaFor(RollupAgg agg, {String target = 'estimate'}) =>
    DatabaseSchema(
      id: 'proj',
      name: 'P',
      icon: 'P',
      color: '#000',
      folderPath: 'P',
      columns: [
        const ColumnDef(key: 'subtasks', type: ColumnType.relation),
        ColumnDef(
          key: 'total',
          type: ColumnType.rollup,
          rollupRelation: 'subtasks',
          rollupTarget: target,
          rollupAgg: agg,
        ),
      ],
      views: const [
        DatabaseView(id: 'all', name: 'All', type: ViewType.table),
      ],
    );

DatabasePageRow _parent(dynamic subtasks) => DatabasePageRow(
      ulid: 'PARENTULID000000000000000P',
      title: 'Parent',
      relativePath: 'P/Parent.md',
      cells: {'subtasks': subtasks},
    );

void main() {
  group('RollupCompute', () {
    test('sum across linked rows', () {
      final schema = _schemaFor(RollupAgg.sum);
      final rows = [
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ];
      final out = RollupCompute.apply(rows, schema);
      expect(out.first.cells['total'], 8);
    });

    test('avg across linked rows', () {
      final schema = _schemaFor(RollupAgg.avg);
      final rows = [
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ];
      final out = RollupCompute.apply(rows, schema);
      expect(out.first.cells['total'], 4);
    });

    test('count of linked rows', () {
      final schema = _schemaFor(RollupAgg.count);
      final rows = [
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ];
      final out = RollupCompute.apply(rows, schema);
      expect(out.first.cells['total'], 2);
    });

    test('min / max', () {
      final rowsMin =
          RollupCompute.apply([
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ], _schemaFor(RollupAgg.min));
      expect(rowsMin.first.cells['total'], 3);

      final rowsMax =
          RollupCompute.apply([
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ], _schemaFor(RollupAgg.max));
      expect(rowsMax.first.cells['total'], 5);
    });

    test('list joins titles when target is missing', () {
      final schema = _schemaFor(RollupAgg.list, target: '');
      final rows = [
        _parent(
            '[[AAAAAAAAAAAAAAAAAAAAAAAAA0]], [[BBBBBBBBBBBBBBBBBBBBBBBBB0]]'),
        _subA,
        _subB,
      ];
      // schema has a non-null target ''; target is read but the cell
      // is empty, so list falls back to the raw cell value (which is '').
      // For meaningful 'list of titles' behaviour, target should be null —
      // we re-build the schema below.
      final schemaTitles = DatabaseSchema(
        id: schema.id,
        name: schema.name,
        icon: schema.icon,
        color: schema.color,
        folderPath: schema.folderPath,
        columns: const [
          ColumnDef(key: 'subtasks', type: ColumnType.relation),
          ColumnDef(
            key: 'total',
            type: ColumnType.rollup,
            rollupRelation: 'subtasks',
            rollupTarget: null,
            rollupAgg: RollupAgg.list,
          ),
        ],
        views: schema.views,
      );
      final out = RollupCompute.apply(rows, schemaTitles);
      expect(out.first.cells['total'], 'Sub A, Sub B');
    });

    test('no relation value → 0 / empty', () {
      final schema = _schemaFor(RollupAgg.sum);
      final rows = [_parent(null), _subA, _subB];
      final out = RollupCompute.apply(rows, schema);
      expect(out.first.cells['total'], 0);
    });

    test('unresolved ULIDs are dropped', () {
      final schema = _schemaFor(RollupAgg.sum);
      final rows = [
        _parent('[[ZZZZZZZZZZZZZZZZZZZZZZZZZ0]]'),
        _subA,
        _subB,
      ];
      final out = RollupCompute.apply(rows, schema);
      expect(out.first.cells['total'], 0);
    });

    test('no rollup columns → identity passthrough', () {
      const plain = DatabaseSchema(
        id: 'x',
        name: 'x',
        icon: 'x',
        color: '#000',
        folderPath: 'x',
        columns: [ColumnDef(key: 'foo', type: ColumnType.text)],
        views: [DatabaseView(id: 'a', name: 'a', type: ViewType.table)],
      );
      final rows = [_subA, _subB];
      final out = RollupCompute.apply(rows, plain);
      expect(identical(out, rows), isTrue);
    });
  });
}
