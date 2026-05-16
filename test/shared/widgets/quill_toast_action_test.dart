import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/quill_toast.dart';

/// E25 — verify the toast convenience helpers (`toastInfo`,
/// `toastWarn`, etc.) forward an `action` + `onAction` pair to the
/// underlying toast controller and that tapping the action button
/// invokes the callback.
void main() {
  testWidgets('toastWarn renders an action button that fires onAction',
      (tester) async {
    var actionTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: makeTheme(Brightness.light, AccentKey.sage),
        builder: (context, child) =>
            QuillToastHost(child: child ?? const SizedBox()),
        home: Scaffold(
          body: Builder(builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () => context.toastWarn(
                  'Sync conflict on notes/a.md',
                  sub: 'server sha 1234abcd…',
                  subMono: true,
                  action: 'Pull',
                  onAction: () => actionTapped = true,
                ),
                child: const Text('show'),
              ),
            );
          }),
        ),
      ),
    );

    // Trigger the toast.
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    // Toast and its Pull action are now in the tree.
    expect(find.text('Sync conflict on notes/a.md'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);

    await tester.tap(find.text('Pull'));
    await tester.pumpAndSettle();
    expect(actionTapped, isTrue);
  });
}
