import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/remote_cursor_overlay.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';
import 'package:my_notion/features/sync/presentation/cubit/presence_cubit.dart';

/// H4c — RemoteCursorOverlay widget tests. State-free widget
/// reading from PresenceCubit; tests inject the rect resolver +
/// a real cubit (no mocks needed — the cubit is bidirectional
/// but for these tests we only push state in via
/// remoteCursorReceived and read the rendered tree).
///
/// Per-test setUp/tearDown ensures the cubit's per-user TTL
/// Timers are cancelled before Flutter's test binding checks for
/// pending timers (otherwise the 5-second default TTL would
/// trip "Timer is still pending" on test teardown).
void main() {
  late PresenceCubit cubit;

  setUp(() {
    // Duration.zero opts out of per-user TTL Timer creation —
    // this widget test scope only exercises render state, not
    // expiry, and pending Timers would trip Flutter's binding
    // leak check (FakeAsync runs in widget tests).
    cubit = PresenceCubit(ttl: Duration.zero);
  });

  tearDown(() async {
    await cubit.close();
  });

  // Stub resolver: returns a deterministic rect per index so
  // tests can position-check without dragging RenderEditable in.
  Rect? rectAt(int idx) {
    if (idx < 0) return null;
    return Rect.fromLTWH(idx * 10.0, idx * 20.0, 2, 16);
  }

  Widget pumpOverlay({CursorRectResolver? resolver}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<PresenceCubit>.value(
          value: cubit,
          child: SizedBox(
            width: 800,
            height: 600,
            child: RemoteCursorOverlay(cursorRectAt: resolver ?? rectAt),
          ),
        ),
      ),
    );
  }

  group('RemoteCursorOverlay (H4c)', () {
    group('rendering', () {
      testWidgets('empty cursor map → no chiclets', (tester) async {
        await tester.pumpWidget(pumpOverlay());
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets('single peer → one chiclet at the resolved rect',
          (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: '01HXALICE000000000000000001',
          pageUlid: 'P',
          cursorIndex: 5,
          color: '#FF5722',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        final positioned =
            tester.widget<Positioned>(find.byType(Positioned));
        // rectAt(5) = LTWH(50, 100, 2, 16) per the stub above.
        expect(positioned.left, 50.0);
        expect(positioned.top, 100.0);
        expect(positioned.height, 16.0);
        expect(positioned.width, 2.0);
      });

      testWidgets('two peers → two chiclets', (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'alice',
          pageUlid: 'P',
          cursorIndex: 1,
          color: '#FF5722',
        ));
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'bob',
          pageUlid: 'P',
          cursorIndex: 3,
          color: '#00AA88',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        expect(find.byType(Positioned), findsNWidgets(2));
      });

      testWidgets('rect resolver returning null drops that peer',
          (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'alice',
          pageUlid: 'P',
          cursorIndex: 5,
          color: '#FF5722',
        ));
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'bob',
          pageUlid: 'P',
          cursorIndex: -1, // resolver returns null
          color: '#00AA88',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        // Only alice's chiclet renders; bob's index resolves to null.
        expect(find.byType(Positioned), findsOneWidget);
      });
    });

    group('label content', () {
      testWidgets('long userId is truncated to 4 chars in the tag',
          (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: '01HXALICE000000000000000001',
          pageUlid: 'P',
          cursorIndex: 0,
          color: '#FF5722',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        expect(find.text('01HX'), findsOneWidget);
      });

      testWidgets('short userId (≤4 chars) renders verbatim',
          (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'bob',
          pageUlid: 'P',
          cursorIndex: 0,
          color: '#FF5722',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        expect(find.text('bob'), findsOneWidget);
      });
    });

    group('input pass-through', () {
      testWidgets('overlay does not intercept hit-tests (IgnorePointer)',
          (tester) async {
        cubit.remoteCursorReceived(const AwarenessMessage(
          userId: 'alice',
          pageUlid: 'P',
          cursorIndex: 1,
          color: '#FF5722',
        ));
        await tester.pumpWidget(pumpOverlay());
        await tester.pump();
        // MaterialApp + Scaffold add their own IgnorePointer
        // ancestors. The overlay's contribution is the one with
        // ignoring: true (default ctor) — count exactly one match.
        final ignoring = tester
            .widgetList<IgnorePointer>(find.byType(IgnorePointer))
            .where((w) => w.ignoring)
            .toList();
        expect(ignoring, hasLength(1));
      });
    });
  });
}
