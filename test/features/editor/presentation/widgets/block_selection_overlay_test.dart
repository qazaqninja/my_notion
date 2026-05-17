import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/cubit/block_selection_cubit.dart';
import 'package:my_notion/features/editor/presentation/widgets/block_selection_overlay.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

void main() {
  group('BlockSelectionOverlay', () {
    Widget harness({
      required BlockSelectionCubit cubit,
      required Rect? Function(String) rectForNode,
    }) {
      return MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [buildTokens(Brightness.light, AccentKey.sage)],
        ),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: SizedBox(
              width: 400,
              height: 400,
              child: BlockSelectionOverlay(rectForNode: rectForNode),
            ),
          ),
        ),
      );
    }

    testWidgets('renders nothing when selection is empty', (tester) async {
      final cubit = BlockSelectionCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(harness(
        cubit: cubit,
        rectForNode: (_) => null,
      ));
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('renders one rect per selected node id', (tester) async {
      final cubit = BlockSelectionCubit();
      addTearDown(cubit.close);
      final rects = {
        'a': const Rect.fromLTWH(0, 0, 100, 20),
        'b': const Rect.fromLTWH(0, 30, 100, 20),
      };
      await tester.pumpWidget(harness(
        cubit: cubit,
        rectForNode: (id) => rects[id],
      ));
      cubit.selectBlock('a');
      await tester.pumpAndSettle();
      expect(find.byType(Positioned), findsOneWidget);
      cubit.toggleBlock('b');
      await tester.pumpAndSettle();
      expect(find.byType(Positioned), findsNWidgets(2));
    });

    testWidgets('skips nodes whose rect is null (off-screen)',
        (tester) async {
      final cubit = BlockSelectionCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(harness(
        cubit: cubit,
        rectForNode: (id) =>
            id == 'a' ? const Rect.fromLTWH(0, 0, 100, 20) : null,
      ));
      cubit.selectBlock('a');
      cubit.toggleBlock('b'); // no rect — should be skipped
      await tester.pumpAndSettle();
      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('updates when cubit emits a new selection', (tester) async {
      final cubit = BlockSelectionCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(harness(
        cubit: cubit,
        rectForNode: (_) => const Rect.fromLTWH(0, 0, 100, 20),
      ));
      cubit.selectBlock('a');
      await tester.pumpAndSettle();
      expect(find.byType(Positioned), findsOneWidget);
      cubit.clearSelection();
      await tester.pumpAndSettle();
      expect(find.byType(Positioned), findsNothing);
    });
  });
}
