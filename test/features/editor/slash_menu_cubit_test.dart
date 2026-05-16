// Ported to bloc_test (RULES.md TS-03) at A9 / M1202 of the 1m-loop plan.
// Slash menu cubit is fully synchronous (no I/O), so all method-call cases
// migrate cleanly to blocTest. Initial-state case stays as a vanilla `test()`
// because blocTest can't express "no emission yet, inspect state" idiomatically.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ui/anchor_rect.dart';
import 'package:my_notion/features/editor/domain/slash_entries.dart';
import 'package:my_notion/features/editor/presentation/cubit/slash_menu_cubit.dart';

const _zeroAnchor = AnchorRect(left: 0, top: 0, right: 0, bottom: 0);

void main() {
  group('SlashMenuCubit', () {
    test('starts closed with every slash entry in results', () {
      final cubit = SlashMenuCubit();
      addTearDown(cubit.close);
      expect(cubit.state.open, isFalse);
      expect(cubit.state.results, equals(kSlashEntries));
      expect(cubit.state.selectedIndex, 0);
    });

    blocTest<SlashMenuCubit, SlashMenuState>(
      'openAt sets anchor + trigger offset, keeps full result list',
      build: SlashMenuCubit.new,
      act: (cubit) => cubit.openAt(
        anchor: const AnchorRect(left: 100, top: 200, right: 420, bottom: 200),
        triggerOffset: 42,
      ),
      verify: (cubit) {
        expect(cubit.state.open, isTrue);
        expect(
          cubit.state.anchorRect,
          equals(const AnchorRect(left: 100, top: 200, right: 420, bottom: 200)),
        );
        expect(cubit.state.triggerOffset, 42);
        expect(cubit.state.results, equals(kSlashEntries));
      },
    );

    blocTest<SlashMenuCubit, SlashMenuState>(
      'setQuery filters by keyword and clamps selectedIndex into range',
      build: SlashMenuCubit.new,
      act: (cubit) {
        cubit
          ..openAt(anchor: _zeroAnchor, triggerOffset: 0)
          ..move(kSlashEntries.length - 1) // push selectedIndex to the end
          ..setQuery('toc');
      },
      verify: (cubit) {
        expect(cubit.state.query, 'toc');
        expect(
          cubit.state.results.length,
          lessThan(kSlashEntries.length),
          reason: 'filter narrows the list',
        );
        expect(
          cubit.state.selectedIndex,
          lessThan(cubit.state.results.length),
          reason: 'selectedIndex re-clamped after filter narrows',
        );
      },
    );

    blocTest<SlashMenuCubit, SlashMenuState>(
      'setQuery is a no-op when the menu is closed',
      build: SlashMenuCubit.new,
      act: (cubit) => cubit.setQuery('something'),
      expect: () => <SlashMenuState>[],
    );

    blocTest<SlashMenuCubit, SlashMenuState>(
      'move and setSelection clamp inside results bounds',
      build: SlashMenuCubit.new,
      act: (cubit) {
        cubit
          ..openAt(anchor: _zeroAnchor, triggerOffset: 0)
          ..move(-100);
        expect(cubit.state.selectedIndex, 0);
        cubit.move(1000);
        expect(cubit.state.selectedIndex, kSlashEntries.length - 1);
        cubit.setSelection(-5);
        expect(
          cubit.state.selectedIndex,
          kSlashEntries.length - 1,
          reason: 'out-of-range selection is rejected',
        );
        cubit.setSelection(2);
      },
      verify: (cubit) {
        expect(cubit.state.selectedIndex, 2);
      },
    );

    blocTest<SlashMenuCubit, SlashMenuState>(
      'dismiss returns to the closed sentinel state',
      build: SlashMenuCubit.new,
      act: (cubit) {
        cubit
          ..openAt(
            anchor: const AnchorRect(left: 5, top: 5, right: 5, bottom: 5),
            triggerOffset: 99,
          )
          ..dismiss();
      },
      verify: (cubit) {
        expect(cubit.state, equals(SlashMenuState.closed));
      },
    );
  });
}
