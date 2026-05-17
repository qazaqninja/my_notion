import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/settings/presentation/widgets/sync_pane.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/quill_tokens.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/quill_toast.dart';

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockVaultBloc extends MockBloc<VaultEvent, VaultState>
    implements VaultBloc {}

/// TS-01 sweep slice 4 — widget tests for SyncPane + _SyncLoginCard
/// extracted to `lib/features/settings/presentation/widgets/
/// sync_pane.dart` in M1423 (FS-04 slice 2). Heavier than slice 3:
/// consumes BOTH SyncBloc and VaultBloc, so the test infra uses a
/// MultiBlocProvider with two MockBlocs. SyncConnectedCard (composed
/// when authed) has its own unit tests in sync_connected_card_test;
/// here we assert the higher-level branching + login-card behavior.
void main() {
  setUpAll(() {
    registerFallbackValue(const SyncLogoutRequested());
    registerFallbackValue(const RefreshFromDisk());
  });

  late ThemeData theme;
  late QuillTokens tokens;

  setUp(() {
    theme = makeTheme(Brightness.light, AccentKey.sage);
    tokens = theme.extension<QuillTokens>()!;
  });

  Widget pumpPane({
    required SyncState syncState,
    VaultState vaultState = const VaultInitial(),
  }) {
    final sync = _MockSyncBloc();
    when(() => sync.state).thenReturn(syncState);
    final vault = _MockVaultBloc();
    when(() => vault.state).thenReturn(vaultState);
    return MaterialApp(
      theme: theme,
      home: QuillToastHost(
        child: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<SyncBloc>.value(value: sync),
              BlocProvider<VaultBloc>.value(value: vault),
            ],
            child: Center(
              // 800-px viewport is enough for the 600-px body text and
              // the login card width.
              child: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: SyncPane(tokens: tokens),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('SyncPane (M1423)', () {
    group('header', () {
      testWidgets('renders the "Sync target" header', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        ));
        expect(find.text('Sync target'), findsOneWidget);
      });
    });

    group('unauthed branch', () {
      testWidgets('renders the login card with Email + Password fields',
          (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        ));
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password (8+ chars)'), findsOneWidget);
      });

      testWidgets('renders the Log in + Sign up buttons', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        ));
        expect(find.text('Log in'), findsOneWidget);
        expect(find.text('Sign up'), findsOneWidget);
      });

      testWidgets('Connected card is NOT rendered', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        ));
        expect(find.text('Connected'), findsNothing);
      });
    });

    group('loading branch', () {
      testWidgets('shows a CircularProgressIndicator next to the buttons',
          (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.loading),
        ));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('Log in button is disabled while busy', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.loading),
        ));
        final button =
            tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
      });
    });

    group('authed branch', () {
      testWidgets('renders SyncConnectedCard ("Connected" + Last push label)',
          (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(
            status: SyncStatus.success,
            token: 'jwt-t',
          ),
        ));
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Last push'), findsOneWidget);
      });

      testWidgets('Login card is NOT rendered', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(
            status: SyncStatus.success,
            token: 'jwt-t',
          ),
        ));
        expect(find.text('Sign up'), findsNothing);
      });
    });

    group('error chip', () {
      testWidgets('lastError renders an error chip', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(
            status: SyncStatus.failure,
            lastError: 'network unreachable',
          ),
        ));
        expect(find.text('network unreachable'), findsOneWidget);
      });

      testWidgets('lastError == "conflict" is suppressed in the chip',
          (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(
            status: SyncStatus.failure,
            lastError: 'conflict',
          ),
        ));
        // Conflict has its own UI in SyncConnectedCard; the pane-level
        // chip explicitly skips it to avoid duplication.
        expect(find.text('conflict'), findsNothing);
      });

      testWidgets('lastError == null renders no chip', (tester) async {
        await tester.pumpWidget(pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        ));
        // Sanity — pane has no chips when there's no error.
        // (The buttons render their own labels; this assertion narrows
        // to the error-chip surface specifically by checking a sample
        // error string that would only appear there.)
        expect(find.text('network unreachable'), findsNothing);
      });
    });
  });

  group('_SyncLoginCard form submit', () {
    testWidgets('Log in button dispatches SyncLoginRequested with credentials',
        (tester) async {
      final sync = _MockSyncBloc();
      when(() => sync.state)
          .thenReturn(const SyncState(status: SyncStatus.initial));
      final vault = _MockVaultBloc();
      when(() => vault.state).thenReturn(const VaultInitial());
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: QuillToastHost(
          child: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<SyncBloc>.value(value: sync),
                BlocProvider<VaultBloc>.value(value: vault),
              ],
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    child: SyncPane(tokens: tokens),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.enterText(find.widgetWithText(TextField, 'Email'),
          'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password (8+ chars)'), 'hunter22');
      await tester.tap(find.text('Log in'));
      await tester.pump();
      verify(() => sync.add(const SyncLoginRequested(
            email: 'user@example.com',
            password: 'hunter22',
          ))).called(1);
    });

    testWidgets('Sign up button dispatches SyncSignupRequested', (tester) async {
      final sync = _MockSyncBloc();
      when(() => sync.state)
          .thenReturn(const SyncState(status: SyncStatus.initial));
      final vault = _MockVaultBloc();
      when(() => vault.state).thenReturn(const VaultInitial());
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: QuillToastHost(
          child: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<SyncBloc>.value(value: sync),
                BlocProvider<VaultBloc>.value(value: vault),
              ],
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    child: SyncPane(tokens: tokens),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.enterText(
          find.widgetWithText(TextField, 'Email'), 'new@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Password (8+ chars)'), 'sekret99');
      await tester.tap(find.text('Sign up'));
      await tester.pump();
      verify(() => sync.add(const SyncSignupRequested(
            email: 'new@example.com',
            password: 'sekret99',
          ))).called(1);
    });

    testWidgets('submit with empty fields is a no-op (no dispatch)',
        (tester) async {
      final sync = _MockSyncBloc();
      when(() => sync.state)
          .thenReturn(const SyncState(status: SyncStatus.initial));
      final vault = _MockVaultBloc();
      when(() => vault.state).thenReturn(const VaultInitial());
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: QuillToastHost(
          child: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<SyncBloc>.value(value: sync),
                BlocProvider<VaultBloc>.value(value: vault),
              ],
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    child: SyncPane(tokens: tokens),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      // Don't enter anything; tap Log in.
      await tester.tap(find.text('Log in'));
      await tester.pump();
      verifyNever(() => sync.add(any()));
    });
  });
}
