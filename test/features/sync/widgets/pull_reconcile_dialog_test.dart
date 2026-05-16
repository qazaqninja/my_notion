import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/sync_file.dart';
import 'package:my_notion/features/sync/presentation/widgets/pull_reconcile_dialog.dart';

import '../../../helpers/test_theme.dart';

/// Minimal test seam for [PullReconcileDialog] (E24). The widget is
/// pure presentation — bloc dispatch lives in the host page — so we
/// verify the callbacks fire on the right buttons and the disabled
/// state matches `body identical` semantics.
void main() {
  Widget pumpDialog({
    required SyncFileBody serverBody,
    required String localBody,
    required VoidCallback onUseServer,
    required VoidCallback onKeepLocal,
  }) {
    return testApp(
      Builder(builder: (context) {
        return PullReconcileDialog(
          serverBody: serverBody,
          localBody: localBody,
          onUseServer: onUseServer,
          onKeepLocal: onKeepLocal,
          forceSideBySide: true,
        );
      }),
    );
  }

  group('PullReconcileDialog (E24)', () {
    final tServer = SyncFileBody(
      summary: SyncFileSummary(
        relpath: 'notes/a.md',
        sha256: 'abcdef1234567890',
        mtime: DateTime.utc(2026, 5, 17),
      ),
      body: '# Server version\nServer line.',
    );

    testWidgets('shows both bodies + relpath + sha header', (tester) async {
      await tester.pumpWidget(pumpDialog(
        serverBody: tServer,
        localBody: '# Local version\nLocal line.',
        onUseServer: () {},
        onKeepLocal: () {},
      ));
      expect(find.text('Pull from server'), findsOneWidget);
      expect(find.textContaining('# Local version'), findsOneWidget);
      expect(find.textContaining('# Server version'), findsOneWidget);
      expect(find.textContaining('abcdef12'), findsOneWidget);
      expect(find.textContaining('notes/a.md'), findsOneWidget);
    });

    testWidgets('"Use server version" invokes onUseServer', (tester) async {
      var called = false;
      await tester.pumpWidget(pumpDialog(
        serverBody: tServer,
        localBody: '# Local',
        onUseServer: () => called = true,
        onKeepLocal: () {},
      ));
      await tester.tap(find.text('Use server version'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets('"Keep local" invokes onKeepLocal', (tester) async {
      var called = false;
      await tester.pumpWidget(pumpDialog(
        serverBody: tServer,
        localBody: '# Local',
        onUseServer: () {},
        onKeepLocal: () => called = true,
      ));
      await tester.tap(find.text('Keep local'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets('identical bodies show match header + disable Use Server',
        (tester) async {
      const same = '# Same content';
      final server = SyncFileBody(
        summary: tServer.summary,
        body: same,
      );
      var serverCalled = false;
      await tester.pumpWidget(pumpDialog(
        serverBody: server,
        localBody: same,
        onUseServer: () => serverCalled = true,
        onKeepLocal: () {},
      ));
      expect(find.text('Server copy matches local'), findsOneWidget);
      // FilledButton with null onPressed is disabled; tapping it shouldn't
      // invoke the callback.
      final filled = find.widgetWithText(FilledButton, 'Use server version');
      final btn = tester.widget<FilledButton>(filled);
      expect(btn.onPressed, isNull);
      await tester.tap(filled, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(serverCalled, isFalse);
    });
  });
}
