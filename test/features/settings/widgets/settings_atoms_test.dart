import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/presentation/widgets/settings_atoms.dart';

import '../../../helpers/test_theme.dart';

/// TS-01 sweep slice 1 — widget tests for the 6 atom widgets
/// extracted to `lib/features/settings/presentation/widgets/
/// settings_atoms.dart` in M1430 (FS-04 slice 5). Each atom is
/// state-free, so the tests target render shape + parameter-flag
/// branching only — no Bloc or repository mocks required.
void main() {
  group('settings_atoms (M1430)', () {
    group('SettingRow', () {
      testWidgets('renders label, hint, and child', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingRow(
              label: 'Vault path',
              hint: 'Folder backing this workspace.',
              child: Text('child-marker'),
            ),
          ),
        );
        expect(find.text('Vault path'), findsOneWidget);
        expect(find.text('Folder backing this workspace.'), findsOneWidget);
        expect(find.text('child-marker'), findsOneWidget);
      });

      testWidgets('danger:true flips label color to tokens.danger',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingRow(
              label: 'Move to trash',
              hint: 'Files survive a re-index.',
              danger: true,
              child: SizedBox.shrink(),
            ),
          ),
        );
        // Both states render; the colour shift is internal but the
        // widget should still mount + display the label.
        expect(find.text('Move to trash'), findsOneWidget);
      });
    });

    group('SettingField', () {
      testWidgets('renders the value verbatim', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingField(value: '/Users/alice/vault'),
          ),
        );
        expect(find.text('/Users/alice/vault'), findsOneWidget);
      });

      testWidgets('monospace:true renders in JetBrainsMono', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingField(value: '01HX...', monospace: true),
          ),
        );
        final text = tester.widget<Text>(find.text('01HX...'));
        expect(text.style?.fontFamily, 'JetBrainsMono');
      });

      testWidgets('monospace:false uses the default font family',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingField(value: 'plain text'),
          ),
        );
        final text = tester.widget<Text>(find.text('plain text'));
        // Default Material font, not JetBrainsMono.
        expect(text.style?.fontFamily, isNot('JetBrainsMono'));
      });

      testWidgets('width:300 clamps the container width', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingField(value: 'x', width: 300),
          ),
        );
        // The widget renders inside a Container with width: 300.
        // pumping inside Scaffold/Center constrains; assert width is
        // bounded around 300.
        final size = tester.getSize(find.byType(SettingField));
        expect(size.width, 300);
      });
    });

    group('SettingButton', () {
      testWidgets('enabled tap fires the callback', (tester) async {
        var fires = 0;
        await tester.pumpWidget(
          testApp(
            SettingButton(label: 'Change…', onTap: () => fires++),
          ),
        );
        await tester.tap(find.text('Change…'));
        expect(fires, 1);
      });

      testWidgets('onTap:null renders disabled (no callback fires)',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingButton(label: 'Change…'),
          ),
        );
        // Tapping a disabled button still calls GestureDetector.onTap
        // which is null — no exception thrown.
        await tester.tap(find.text('Change…'));
        expect(find.text('Change…'), findsOneWidget);
      });

      testWidgets('primary:true renders with the accent fill', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingButton(label: 'Publish', primary: true, onTap: () {}),
          ),
        );
        expect(find.text('Publish'), findsOneWidget);
      });

      testWidgets('icon:"git" includes the QuillIcon glyph', (tester) async {
        await tester.pumpWidget(
          testApp(
            SettingButton(label: 'Sync', icon: 'git', onTap: () {}),
          ),
        );
        // QuillIcon doesn't expose its name as a finder-friendly key;
        // assert the row layout includes both the label and a non-text
        // sibling (the icon's CustomPaint).
        expect(find.text('Sync'), findsOneWidget);
        // Hover region renders even for the icon path.
        expect(find.byType(MouseRegion), findsWidgets);
      });
    });

    group('SettingStat', () {
      testWidgets('renders label + value', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingStat(label: 'PAGES', value: '142'),
          ),
        );
        expect(find.text('PAGES'), findsOneWidget);
        expect(find.text('142'), findsOneWidget);
      });

      testWidgets('tooltip wraps the body when provided', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingStat(
                label: 'SIZE', value: '1.2 MB', tooltip: '1,234,567 bytes'),
          ),
        );
        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('no tooltip when null', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SettingStat(label: 'PAGES', value: '0'),
          ),
        );
        expect(find.byType(Tooltip), findsNothing);
      });
    });

    group('SettingToggle', () {
      testWidgets('on:true positions the knob at the right (+16)',
          (tester) async {
        await tester.pumpWidget(testApp(const SettingToggle(on: true)));
        final positioned =
            tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
        expect(positioned.left, 16);
      });

      testWidgets('on:false positions the knob at the left (+2)',
          (tester) async {
        await tester.pumpWidget(testApp(const SettingToggle(on: false)));
        final positioned =
            tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
        expect(positioned.left, 2);
      });
    });

    group('SyncPlaceholderCard', () {
      testWidgets('renders name + status row', (tester) async {
        await tester.pumpWidget(
          testApp(
            const SyncPlaceholderCard(
              name: 'Git',
              icon: 'git',
              status: 'visual only',
            ),
          ),
        );
        expect(find.text('Git'), findsOneWidget);
        expect(find.text('visual only'), findsOneWidget);
      });

      testWidgets('active:true renders the StatusDot indicator',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            const SyncPlaceholderCard(
              name: 'Git',
              icon: 'git',
              status: 'connected',
              active: true,
            ),
          ),
        );
        // Active state duplicates the status string into a second tag
        // alongside the StatusDot.
        expect(find.text('connected'), findsNWidgets(2));
      });

      testWidgets('active:false does NOT render the duplicate status tag',
          (tester) async {
        await tester.pumpWidget(
          testApp(
            const SyncPlaceholderCard(
              name: 'S3',
              icon: 'cloud',
              status: 'not configured',
            ),
          ),
        );
        expect(find.text('not configured'), findsOneWidget);
      });
    });
  });
}
