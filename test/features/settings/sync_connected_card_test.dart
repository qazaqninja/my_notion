import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/sync/domain/entities/sync_file.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';
import 'package:my_notion/features/sync/presentation/widgets/sync_connected_card.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/quill_tokens.dart';
import 'package:my_notion/shared/theme/tokens.dart';

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

/// E26 — verifies the standalone [SyncConnectedCard] surfaces last-push
/// + last-conflict + a Retry pull action that dispatches
/// `SyncFetchFileRequested`. Pumped in isolation (without the full
/// settings_page chrome) so the assertions live or die on this widget
/// alone.
void main() {
  setUpAll(() {
    // SyncEvent is sealed; register a concrete subtype as the fallback
    // value mocktail uses when matching `any()` of the event type.
    registerFallbackValue(const SyncLogoutRequested());
  });

  Widget pumpCard(SyncState state, SyncBloc bloc) {
    final theme = makeTheme(Brightness.light, AccentKey.sage);
    final tokens = theme.extension<QuillTokens>()!;
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: BlocProvider<SyncBloc>.value(
          value: bloc,
          child: Center(
            child: SizedBox(
              width: 600,
              child: SyncConnectedCard(state: state, tokens: tokens),
            ),
          ),
        ),
      ),
    );
  }

  group('SyncConnectedCard (E26)', () {
    testWidgets('clean state shows "—" for last push, no conflict',
        (tester) async {
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(
        const SyncState(status: SyncStatus.connected, token: 'jwt-t'),
      );
      await tester.pumpWidget(pumpCard(
        const SyncState(status: SyncStatus.connected, token: 'jwt-t'),
        bloc,
      ));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Last push'), findsOneWidget);
      expect(find.textContaining('—'), findsWidgets);
      expect(find.text('Unresolved conflict'), findsNothing);
      expect(find.text('Retry pull'), findsNothing);
    });

    testWidgets('recent push renders with relpath + sha + relative time',
        (tester) async {
      final state = SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        lastPush: SyncFileSummary(
          relpath: 'notes/a.md',
          sha256: 'cafef00ddeadbeef0011',
          mtime: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.textContaining('notes/a.md'), findsOneWidget);
      expect(find.textContaining('cafef00d'), findsOneWidget);
      expect(find.textContaining('s ago'), findsOneWidget);
    });

    testWidgets('unresolved conflict shows banner + Retry pull dispatches event',
        (tester) async {
      final state = SyncState(
        status: SyncStatus.error,
        token: 'jwt-t',
        lastError: 'conflict',
        lastConflict: SyncFileSummary(
          relpath: 'notes/conflict.md',
          sha256: '12345678abcd',
          mtime: DateTime.utc(2026, 5, 17),
        ),
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));

      expect(find.text('Unresolved conflict'), findsOneWidget);
      expect(find.textContaining('notes/conflict.md'), findsOneWidget);
      expect(find.textContaining('12345678'), findsOneWidget);

      await tester.tap(find.text('Retry pull'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(any(
            that: isA<SyncFetchFileRequested>().having(
              (e) => e.relpath,
              'relpath',
              'notes/conflict.md',
            ),
          ))).called(1);
    });

    testWidgets('Log out dispatches SyncLogoutRequested', (tester) async {
      const state = SyncState(status: SyncStatus.connected, token: 'jwt-t');
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(any(that: isA<SyncLogoutRequested>())))
          .called(1);
    });
  });

  group('SyncConnectedCard push-all button (E32)', () {
    testWidgets('onPushAll == null → button hidden', (tester) async {
      const state = SyncState(status: SyncStatus.connected, token: 'jwt-t');
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.text('Push all unsynced'), findsNothing);
    });

    testWidgets('onPushAll provided → button visible and tap fires it',
        (tester) async {
      const state = SyncState(status: SyncStatus.connected, token: 'jwt-t');
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      var called = false;
      final theme = makeTheme(Brightness.light, AccentKey.sage);
      final tokens = theme.extension<QuillTokens>()!;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: BlocProvider<SyncBloc>.value(
            value: bloc,
            child: Center(
              child: SizedBox(
                width: 600,
                child: SyncConnectedCard(
                  state: state,
                  tokens: tokens,
                  onPushAll: () => called = true,
                ),
              ),
            ),
          ),
        ),
      ));

      expect(find.text('Push all unsynced'), findsOneWidget);
      await tester.tap(find.text('Push all unsynced'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });

  group('SyncConnectedCard push queue depth (E30)', () {
    testWidgets('pendingPushes == 0 → no "Syncing…" row', (tester) async {
      const state = SyncState(status: SyncStatus.connected, token: 'jwt-t');
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.textContaining('Syncing'), findsNothing);
    });

    testWidgets('pendingPushes == 1 → "Syncing 1 file…"', (tester) async {
      const state = SyncState(
        status: SyncStatus.busy,
        token: 'jwt-t',
        pendingPushes: 1,
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.text('Syncing 1 file…'), findsOneWidget);
    });

    testWidgets('pendingPushes == 4 → plural copy', (tester) async {
      const state = SyncState(
        status: SyncStatus.busy,
        token: 'jwt-t',
        pendingPushes: 4,
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.text('Syncing 4 files…'), findsOneWidget);
    });
  });

  group('SyncConnectedCard network error banner (E28)', () {
    testWidgets('un-classified lastError renders banner + Retry now',
        (tester) async {
      const state = SyncState(
        status: SyncStatus.error,
        token: 'jwt-t',
        lastError: 'connection_timed_out',
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);

      await tester.pumpWidget(pumpCard(state, bloc));

      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('connection_timed_out'), findsOneWidget);

      await tester.tap(find.text('Retry now'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(any(that: isA<SyncListRequested>())))
          .called(1);
    });

    testWidgets('structured errors do NOT render the network banner',
        (tester) async {
      // conflict is rendered by the "Unresolved conflict" banner, not
      // the network one.
      final state = SyncState(
        status: SyncStatus.error,
        token: 'jwt-t',
        lastError: 'conflict',
        lastConflict: SyncFileSummary(
          relpath: 'a.md',
          sha256: 'sha-x',
          mtime: DateTime.utc(2026, 5, 17),
        ),
      );
      final bloc = _MockSyncBloc();
      when(() => bloc.state).thenReturn(state);

      await tester.pumpWidget(pumpCard(state, bloc));
      expect(find.text('Network error'), findsNothing);
    });

    test('isNetworkError classifies known codes correctly', () {
      expect(isNetworkError('connection_timed_out'), isTrue);
      expect(isNetworkError('socket_closed'), isTrue);
      // Structured codes filtered out.
      for (final code in [
        'conflict',
        'not_found',
        'token_invalid',
        'not_authenticated',
        'invalid_credentials',
        'invalid_signup',
        'email_taken',
      ]) {
        expect(isNetworkError(code), isFalse,
            reason: '$code should be classified as structured, not network');
      }
      expect(isNetworkError(null), isFalse);
      expect(isNetworkError(''), isFalse);
    });
  });

  group('syncRelativeTime (E26)', () {
    test('< 5 s → "now"', () {
      final t = DateTime.now().subtract(const Duration(seconds: 2));
      expect(syncRelativeTime(t), 'now');
    });
    test('< 60 s → "Xs ago"', () {
      final t = DateTime.now().subtract(const Duration(seconds: 30));
      expect(syncRelativeTime(t), '30s ago');
    });
    test('minutes / hours / days', () {
      expect(
        syncRelativeTime(DateTime.now().subtract(const Duration(minutes: 5))),
        '5m ago',
      );
      expect(
        syncRelativeTime(DateTime.now().subtract(const Duration(hours: 3))),
        '3h ago',
      );
      expect(
        syncRelativeTime(DateTime.now().subtract(const Duration(days: 2))),
        '2d ago',
      );
    });
    test('future timestamps fall back to "just now"', () {
      final t = DateTime.now().add(const Duration(minutes: 5));
      expect(syncRelativeTime(t), 'just now');
    });
  });
}
