import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/core/ui/anchor_rect.dart';
import 'package:my_notion/features/relations/domain/usecases/search_pages.dart';
import 'package:my_notion/features/relations/presentation/cubit/relation_picker_cubit.dart';

class _MockSearchPages extends Mock implements SearchPages {}

PageSearchResult _result(String title) => PageSearchResult(
      ulid: '01HX0V000000000000000000${title.codeUnitAt(0).toRadixString(16).padLeft(2, '0').toUpperCase()}',
      title: title,
      relativePath: '$title.md',
      snippet: '',
    );

void main() {
  late _MockSearchPages search;

  setUp(() {
    search = _MockSearchPages();
    when(() => search.call(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => [_result('Alpha'), _result('Beta')]);
  });

  group('RelationPickerCubit', () {
    test('starts closed with empty results', () {
      final cubit = RelationPickerCubit(search);
      expect(cubit.state.open, isFalse);
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.selectedIndex, 0);
      cubit.close();
    });

    test('openAt sets anchor + sourceOffset, then resolves search results', () async {
      final cubit = RelationPickerCubit(search);
      const anchor = AnchorRect(left: 50, top: 80, right: 370, bottom: 80);
      await cubit.openAt(anchor: anchor, sourceOffset: 17);
      expect(cubit.state.open, isTrue);
      expect(cubit.state.anchorRect, equals(anchor));
      expect(cubit.state.anchorStartOffset, 17);
      expect(cubit.state.results.length, 2);
      expect(cubit.state.selectedIndex, 0);
      cubit.close();
    });

    test('setQuery resets selectedIndex and re-runs the search', () async {
      final cubit = RelationPickerCubit(search);
      await cubit.openAt(
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        sourceOffset: 0,
      );
      cubit.move(1); // selectedIndex = 1
      expect(cubit.state.selectedIndex, 1);

      when(() => search.call('alp', limit: any(named: 'limit')))
          .thenAnswer((_) async => [_result('Alpha')]);
      await cubit.setQuery('alp');

      expect(cubit.state.query, 'alp');
      expect(cubit.state.results, hasLength(1));
      expect(cubit.state.selectedIndex, 0,
          reason: 'setQuery resets selection back to top');
      cubit.close();
    });

    test('setQuery on a closed picker is a no-op', () async {
      final cubit = RelationPickerCubit(search);
      final before = cubit.state;
      await cubit.setQuery('whatever');
      expect(cubit.state, equals(before));
      verifyNever(() => search.call(any(), limit: any(named: 'limit')));
      cubit.close();
    });

    test('move clamps the selectedIndex into the results range', () async {
      final cubit = RelationPickerCubit(search);
      await cubit.openAt(
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        sourceOffset: 0,
      );
      cubit.move(-100);
      expect(cubit.state.selectedIndex, 0);
      cubit.move(100);
      expect(cubit.state.selectedIndex, 1);
      cubit.close();
    });

    test('dismiss returns to the closed sentinel state', () async {
      final cubit = RelationPickerCubit(search);
      await cubit.openAt(
        anchor: const AnchorRect(left: 5, top: 5, right: 5, bottom: 5),
        sourceOffset: 99,
      );
      cubit.dismiss();
      expect(cubit.state, equals(RelationPickerState.closed));
      cubit.close();
    });

    test('selectedResult reflects the highlighted row', () async {
      final cubit = RelationPickerCubit(search);
      await cubit.openAt(
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        sourceOffset: 0,
      );
      expect(cubit.state.selectedResult?.title, 'Alpha');
      cubit.move(1);
      expect(cubit.state.selectedResult?.title, 'Beta');
      cubit.close();
    });
  });
}
