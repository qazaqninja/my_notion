import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/presentation/widgets/settings_nav.dart';

import '../../../helpers/test_theme.dart';

/// TS-01 sweep slice 2 — widget tests for SettingsNav, the 220-px
/// left rail extracted to
/// `lib/features/settings/presentation/widgets/settings_nav.dart`
/// in M1426 (FS-04 slice 3). SettingsNav is state-free with two
/// props (`active` id + `onSelect` callback) — no Bloc mocks
/// required. Same testApp() pattern as M1432.
void main() {
  group('SettingsNav (M1426)', () {
    group('group headers', () {
      testWidgets('renders all 4 group headers in uppercase', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingsNav(active: 'vault', onSelect: (_) {}),
          ),
        );
        expect(find.text('WORKSPACE'), findsOneWidget);
        expect(find.text('SYNC'), findsOneWidget);
        expect(find.text('ACCESS'), findsOneWidget);
        expect(find.text('DATA'), findsOneWidget);
      });
    });

    group('row rendering', () {
      testWidgets('renders all 11 row labels from the 4-group static list',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingsNav(active: 'vault', onSelect: (_) {}),
          ),
        );
        // Workspace
        expect(find.text('Vault'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Sidebar'), findsOneWidget);
        // Sync
        expect(find.text('Sync target'), findsOneWidget);
        expect(find.text('Git'), findsOneWidget);
        expect(find.text('S3 / WebDAV'), findsOneWidget);
        // Access
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Permissions'), findsOneWidget);
        // Data
        expect(find.text('Forms'), findsOneWidget);
        expect(find.text('Export & Backup'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
      });
    });

    group('active state', () {
      testWidgets('active row label uses FontWeight.w500', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingsNav(active: 'sync', onSelect: (_) {}),
          ),
        );
        final activeText = tester.widget<Text>(find.text('Sync target'));
        expect(activeText.style, isNotNull);
        expect(activeText.style!.fontWeight, FontWeight.w500);
      });

      testWidgets('inactive row label uses FontWeight.w400', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingsNav(active: 'sync', onSelect: (_) {}),
          ),
        );
        // 'Vault' is in the Workspace group, not active when active='sync'.
        final inactiveText = tester.widget<Text>(find.text('Vault'));
        expect(inactiveText.style, isNotNull);
        expect(inactiveText.style!.fontWeight, FontWeight.w400);
      });

      testWidgets('only one row is active at a time', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingsNav(active: 'forms', onSelect: (_) {}),
          ),
        );
        // Each of the 11 row labels is a Text widget; group headers
        // are also Text widgets (4 of them) — so 15 Texts total. The
        // active styling lives on the row label only, not headers.
        // Count Texts with FontWeight.w500 = exactly 1 (the active row).
        final boldRows = tester
            .widgetList<Text>(find.byType(Text))
            .where((t) => t.style?.fontWeight == FontWeight.w500)
            .toList();
        expect(boldRows, hasLength(1));
        expect(boldRows.first.data, 'Forms');
      });
    });

    group('onSelect callback', () {
      testWidgets('tapping a row fires onSelect with its id', (tester) async {
        String? lastTapped;
        await tester.pumpWidget(
          testApp(
            SettingsNav(
              active: 'vault',
              onSelect: (id) => lastTapped = id,
            ),
          ),
        );
        await tester.tap(find.text('Appearance'));
        expect(lastTapped, 'theme');
      });

      testWidgets('tapping each of three different rows fires their own ids',
          (tester) async {
        final fired = <String>[];
        await tester.pumpWidget(
          testApp(
            SettingsNav(
              active: 'vault',
              onSelect: fired.add,
            ),
          ),
        );
        // Tap an item from each of three groups to exercise the
        // tuple → id wiring across the static _groups list.
        await tester.tap(find.text('Vault'));
        await tester.tap(find.text('Git'));
        await tester.tap(find.text('Permissions'));
        await tester.tap(find.text('Export & Backup'));
        expect(fired, ['vault', 'git', 'perms', 'export']);
      });

      testWidgets('tapping the active row still fires onSelect',
          (tester) async {
        String? lastTapped;
        await tester.pumpWidget(
          testApp(
            SettingsNav(
              active: 'forms',
              onSelect: (id) => lastTapped = id,
            ),
          ),
        );
        // The nav doesn't suppress repeat selections — the consumer
        // decides whether re-tapping the active row is a no-op.
        await tester.tap(find.text('Forms'));
        expect(lastTapped, 'forms');
      });
    });
  });
}
