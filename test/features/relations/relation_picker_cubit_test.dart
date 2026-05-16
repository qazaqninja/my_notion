// Ported to bloc_test (RULES.md TS-03) at A8 / M1200 of the 1m-loop plan.
// Initial-state and "no-op when closed" cases stay as vanilla tests since
// blocTest can't elegantly express "no emission expected, but inspect
// state" or "no mock interaction expected".

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/core/ui/anchor_rect.dart';
import 'package:my_notion/features/relations/domain/usecases/search_pages.dart';
import 'package:my_notion/features/relations/presentation/cubit/relation_picker_cubit.dart';

class _MockSearchPages extends Mock implements SearchPages {}

PageSearchResult _result(String title) => PageSearchResult(
      ulid: '01HX0V000000000000000000'
          '${title.codeUnitAt(0).toRadixString(16).padLeft(2, '0').toUpperCase()}',
      title: title,
      relativePath: '$title.md',
      snippet: '',
    );

const _zeroAnchor = AnchorRect(left: 0, top: 0, right: 0, bottom: 0);

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
      addTearDown(cubit.close);
      expect(cubit.state.open, isFalse);
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.selectedIndex, 0);
    });

    blocTest<RelationPickerCubit, RelationPickerState>(
      'openAt sets anchor + sourceOffset, then resolves search results',
      build: () => RelationPickerCubit(search),
      act: (cubit) => cubit.openAt(
        anchor: const AnchorRect(left: 50, top: 80, right: 370, bottom: 80),
        sourceOffset: 17,
      ),
      verify: (cubit) {
        expect(cubit.state.open, isTrue);
        expect(
          cubit.state.anchorRect,
          equals(const AnchorRect(left: 50, top: 80, right: 370, bottom: 80)),
        );
        expect(cubit.state.anchorStartOffset, 17);
        expect(cubit.state.results.length, 2);
        expect(cubit.state.selectedIndex, 0);
      },
    );

    blocTest<RelationPickerCubit, RelationPickerState>(
      'setQuery resets selectedIndex and re-runs the search',
      build: () => RelationPickerCubit(search),
      act: (cubit) async {
        await cubit.openAt(anchor: _zeroAnchor, sourceOffset: 0);
        cubit.move(1); // selectedIndex = 1
        when(() => search.call('alp', limit: any(named: 'limit')))
            .thenAnswer((_) async => [_result('Alpha')]);
        await cubit.setQuery('alp');
      },
      verify: (cubit) {
        expect(cubit.state.query, 'alp');
        expect(cubit.state.results, hasLength(1));
        expect(
          cubit.state.selectedIndex,
          0,
          reason: 'setQuery resets selection back to top',
        );
      },
    );

    blocTest<RelationPickerCubit, RelationPickerState>(
      'setQuery on a closed picker emits nothing and skips the search',
      build: () => RelationPickerCubit(search),
      act: (cubit) => cubit.setQuery('whatever'),
      expect: () => <RelationPickerState>[],
      verify: (cubit) {
        verifyNever(() => search.call(any(), limit: any(named: 'limit')));
      },
    );

    blocTest<RelationPickerCubit, RelationPickerState>(
      'move clamps the selectedIndex into the results range',
      build: () => RelationPickerCubit(search),
      act: (cubit) async {
        await cubit.openAt(anchor: _zeroAnchor, sourceOffset: 0);
        cubit.move(-100);
        expect(cubit.state.selectedIndex, 0);
        cubit.move(100);
      },
      verify: (cubit) {
        expect(cubit.state.selectedIndex, 1);
      },
    );

    blocTest<RelationPickerCubit, RelationPickerState>(
      'dismiss returns to the closed sentinel state',
      build: () => RelationPickerCubit(search),
      act: (cubit) async {
        await cubit.openAt(
          anchor: const AnchorRect(left: 5, top: 5, right: 5, bottom: 5),
          sourceOffset: 99,
        );
        cubit.dismiss();
      },
      verify: (cubit) {
        expect(cubit.state, equals(RelationPickerState.closed));
      },
    );

    blocTest<RelationPickerCubit, RelationPickerState>(
      'selectedResult reflects the highlighted row',
      build: () => RelationPickerCubit(search),
      act: (cubit) async {
        await cubit.openAt(anchor: _zeroAnchor, sourceOffset: 0);
        expect(cubit.state.selectedResult?.title, 'Alpha');
        cubit.move(1);
      },
      verify: (cubit) {
        expect(cubit.state.selectedResult?.title, 'Beta');
      },
    );
  });
}
