import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/find_bar.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required TextEditingController controller,
  required int matches,
  required int cursor,
  ValueChanged<String>? onChanged,
  VoidCallback? onPrev,
  VoidCallback? onNext,
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: [buildTokens(Brightness.light, AccentKey.sage)],
      ),
      home: Scaffold(
        body: FindBar(
          controller: controller,
          focusNode: FocusNode(),
          matches: matches,
          cursor: cursor,
          onChanged: onChanged ?? (_) {},
          onPrev: onPrev ?? () {},
          onNext: onNext ?? () {},
          onClose: onClose ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  group('FindBar', () {
    group('render', () {
      testWidgets('renders the query TextField + hint', (tester) async {
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 0,
          cursor: 0,
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Find in page…'), findsOneWidget);
      });

      testWidgets('renders "no matches" label when matches == 0', (
        tester,
      ) async {
        await _pumpBar(
          tester,
          controller: TextEditingController(text: 'xyz'),
          matches: 0,
          cursor: 0,
        );
        expect(find.text('no matches'), findsOneWidget);
      });

      testWidgets('renders "N / M" label when matches > 0', (tester) async {
        await _pumpBar(
          tester,
          controller: TextEditingController(text: 'foo'),
          matches: 17,
          cursor: 3,
        );
        expect(find.text('3 / 17'), findsOneWidget);
      });
    });

    group('callbacks', () {
      testWidgets('onChanged fires on text change', (tester) async {
        final calls = <String>[];
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 0,
          cursor: 0,
          onChanged: calls.add,
        );
        await tester.enterText(find.byType(TextField), 'hello');
        expect(calls, ['hello']);
      });

      testWidgets('onNext fires when next-arrow tapped (matches>0)', (
        tester,
      ) async {
        var calls = 0;
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 5,
          cursor: 1,
          onNext: () => calls++,
        );
        await tester.tap(find.byTooltip('Next match (⌘G)'));
        expect(calls, 1);
      });

      testWidgets('onPrev fires when prev-arrow tapped (matches>0)', (
        tester,
      ) async {
        var calls = 0;
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 5,
          cursor: 1,
          onPrev: () => calls++,
        );
        await tester.tap(find.byTooltip('Previous match (⌘⇧G)'));
        expect(calls, 1);
      });

      testWidgets('next/prev are disabled when matches == 0', (tester) async {
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 0,
          cursor: 0,
        );
        final nextBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
        );
        final prevBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up),
        );
        expect(nextBtn.onPressed, isNull);
        expect(prevBtn.onPressed, isNull);
      });

      testWidgets('onClose fires when close button tapped', (tester) async {
        var calls = 0;
        await _pumpBar(
          tester,
          controller: TextEditingController(),
          matches: 0,
          cursor: 0,
          onClose: () => calls++,
        );
        await tester.tap(find.byTooltip('Close (Esc)'));
        expect(calls, 1);
      });

      testWidgets('onSubmitted (Enter on TextField) routes to onNext', (
        tester,
      ) async {
        var calls = 0;
        await _pumpBar(
          tester,
          controller: TextEditingController(text: 'foo'),
          matches: 3,
          cursor: 1,
          onNext: () => calls++,
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(calls, 1);
      });
    });
  });
}
