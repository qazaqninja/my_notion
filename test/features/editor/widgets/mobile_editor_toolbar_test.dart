import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/mobile_editor_toolbar.dart';

import '../../../helpers/test_theme.dart';

/// G2 — sticky bottom-bar surfacing the most-used kebab actions on
/// mobile. Pure-presentational widget so the test pumps it with
/// callback spies and asserts the wire-up.
void main() {
  testWidgets('Renders 3 buttons when hasForms is false', (tester) async {
    await tester.pumpWidget(testApp(
      MobileEditorToolbar(
        onSetReminder: () {},
        onPublish: () {},
        onViewFormSubmissions: () {},
        onMore: () {},
      ),
    ));
    expect(find.byTooltip('Set reminder'), findsOneWidget);
    expect(find.byTooltip('Publish & copy link'), findsOneWidget);
    expect(find.byTooltip('View form submissions'), findsNothing);
    expect(find.byTooltip('More actions'), findsOneWidget);
  });

  testWidgets('Inbox button visible when hasForms is true', (tester) async {
    await tester.pumpWidget(testApp(
      MobileEditorToolbar(
        onSetReminder: () {},
        onPublish: () {},
        onViewFormSubmissions: () {},
        onMore: () {},
        hasForms: true,
      ),
    ));
    expect(find.byTooltip('View form submissions'), findsOneWidget);
  });

  testWidgets('isPublished swaps the link button tooltip to "Unpublish"',
      (tester) async {
    await tester.pumpWidget(testApp(
      MobileEditorToolbar(
        onSetReminder: () {},
        onPublish: () {},
        onViewFormSubmissions: () {},
        onMore: () {},
        isPublished: true,
      ),
    ));
    expect(find.byTooltip('Unpublish'), findsOneWidget);
    expect(find.byTooltip('Publish & copy link'), findsNothing);
  });

  testWidgets('Each button invokes its callback when tapped',
      (tester) async {
    var reminderCalls = 0;
    var publishCalls = 0;
    var inboxCalls = 0;
    var moreCalls = 0;
    await tester.pumpWidget(testApp(
      MobileEditorToolbar(
        onSetReminder: () => reminderCalls++,
        onPublish: () => publishCalls++,
        onViewFormSubmissions: () => inboxCalls++,
        onMore: () => moreCalls++,
        hasForms: true,
      ),
    ));

    await tester.tap(find.byTooltip('Set reminder'));
    await tester.tap(find.byTooltip('Publish & copy link'));
    await tester.tap(find.byTooltip('View form submissions'));
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(reminderCalls, 1);
    expect(publishCalls, 1);
    expect(inboxCalls, 1);
    expect(moreCalls, 1);
  });
}
