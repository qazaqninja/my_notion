import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ui/anchor_rect.dart';
import 'package:my_notion/features/editor/domain/slash_entries.dart';
import 'package:my_notion/features/editor/presentation/cubit/slash_menu_cubit.dart';

void main() {
  group('SlashMenuCubit', () {
    test('starts closed with every slash entry in results', () {
      final cubit = SlashMenuCubit();
      expect(cubit.state.open, isFalse);
      expect(cubit.state.results, equals(kSlashEntries));
      expect(cubit.state.selectedIndex, 0);
      cubit.close();
    });

    test('openAt sets anchor + trigger offset, keeps full result list', () {
      final cubit = SlashMenuCubit();
      const anchor = AnchorRect(left: 100, top: 200, right: 420, bottom: 200);
      cubit.openAt(anchor: anchor, triggerOffset: 42);
      expect(cubit.state.open, isTrue);
      expect(cubit.state.anchorRect, equals(anchor));
      expect(cubit.state.triggerOffset, 42);
      expect(cubit.state.results, equals(kSlashEntries));
      cubit.close();
    });

    test('setQuery filters by keyword and clamps selectedIndex into range', () {
      final cubit = SlashMenuCubit();
      cubit.openAt(
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        triggerOffset: 0,
      );
      cubit.move(kSlashEntries.length - 1); // push selectedIndex to the end
      cubit.setQuery('toc');
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
      cubit.close();
    });

    test('setQuery is a no-op when the menu is closed', () {
      final cubit = SlashMenuCubit();
      final before = cubit.state;
      cubit.setQuery('something');
      expect(cubit.state, equals(before));
      cubit.close();
    });

    test('move and setSelection clamp inside results bounds', () {
      final cubit = SlashMenuCubit();
      cubit.openAt(
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        triggerOffset: 0,
      );
      cubit.move(-100);
      expect(cubit.state.selectedIndex, 0);
      cubit.move(1000);
      expect(cubit.state.selectedIndex, kSlashEntries.length - 1);
      cubit.setSelection(-5);
      expect(cubit.state.selectedIndex, kSlashEntries.length - 1,
          reason: 'out-of-range selection is rejected');
      cubit.setSelection(2);
      expect(cubit.state.selectedIndex, 2);
      cubit.close();
    });

    test('dismiss returns to the closed sentinel state', () {
      final cubit = SlashMenuCubit();
      cubit.openAt(
        anchor: const AnchorRect(left: 5, top: 5, right: 5, bottom: 5),
        triggerOffset: 99,
      );
      cubit.dismiss();
      expect(cubit.state, equals(SlashMenuState.closed));
      cubit.close();
    });
  });
}
