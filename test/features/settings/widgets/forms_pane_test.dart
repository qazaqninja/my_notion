import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart';
import 'package:my_notion/features/forms/domain/entities/form_submission.dart';
import 'package:my_notion/features/forms/domain/repositories/form_bearing_pages_repository.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';
import 'package:my_notion/features/settings/presentation/widgets/forms_pane.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/quill_tokens.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/quill_toast.dart';

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockFormBearingPagesRepository extends Mock
    implements FormBearingPagesRepository {}

class _MockFormsRepository extends Mock implements FormsRepository {}

/// TS-01 sweep slice 5 — widget tests for FormsPane + private
/// _FormBearingPageRow / _FormsEmptyState / _FormsErrorRow extracted
/// to `lib/features/settings/presentation/widgets/forms_pane.dart`
/// in M1421 (FS-04 slice 1). The pane creates its own
/// FormBearingPagesCubit via BlocProvider(create:..load()), so the
/// test infrastructure can't inject a MockCubit directly — instead
/// it stubs FormBearingPagesRepository so the real Cubit's load()
/// resolves to a known state. This pattern keeps the cubit's actual
/// state transitions in the integration loop.
void main() {
  setUpAll(() {
    registerFallbackValue(const SyncLogoutRequested());
  });

  late ThemeData theme;
  late QuillTokens tokens;

  setUp(() {
    theme = makeTheme(Brightness.light, AccentKey.sage);
    tokens = theme.extension<QuillTokens>()!;
  });

  /// Returns the widget tree plus references to every mock so tests
  /// can stub repo.loadAll() per-test and verify outbound calls.
  /// Mirrors the M1441 record-returning pattern.
  ({
    Widget widget,
    _MockSyncBloc sync,
    _MockFormBearingPagesRepository pagesRepo,
    _MockFormsRepository formsRepo,
  }) pumpPane({SyncState? syncState}) {
    final sync = _MockSyncBloc();
    when(() => sync.state)
        .thenReturn(syncState ?? const SyncState(status: SyncStatus.initial));
    final pagesRepo = _MockFormBearingPagesRepository();
    final formsRepo = _MockFormsRepository();
    final widget = MaterialApp(
      theme: theme,
      home: QuillToastHost(
        child: Scaffold(
          body: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<FormBearingPagesRepository>.value(
                  value: pagesRepo),
              RepositoryProvider<FormsRepository>.value(value: formsRepo),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<SyncBloc>.value(value: sync),
              ],
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    child: FormsPane(tokens: tokens),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (
      widget: widget,
      sync: sync,
      pagesRepo: pagesRepo,
      formsRepo: formsRepo,
    );
  }

  group('FormsPane (M1421)', () {
    group('header + body copy', () {
      testWidgets('renders the "Forms" header', (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll).thenAnswer((_) async => []);
        await tester.pumpWidget(tree.widget);
        await tester.pump();
        expect(find.text('Forms'), findsOneWidget);
      });
    });

    group('loading state', () {
      testWidgets('shows a CircularProgressIndicator while load is pending',
          (tester) async {
        final tree = pumpPane();
        // Future that never completes within the test window keeps the
        // cubit in loading.
        final never = Completer<List<FormBearingPage>>();
        when(tree.pagesRepo.loadAll)
            .thenAnswer((_) => never.future);
        await tester.pumpWidget(tree.widget);
        // pump once so the BlocProvider create-callback fires + the
        // cubit emits loading.
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Resolve the future so the addTearDown doesn't leak it.
        never.complete([]);
      });
    });

    group('failure state', () {
      testWidgets('renders _FormsErrorRow with the typed error message',
          (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll).thenThrow(
            const FormBearingPagesLoadException('database is locked'));
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('Could not load form-bearing pages'),
            findsOneWidget);
        expect(find.textContaining('database is locked'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('Retry button re-invokes repo.loadAll()', (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll)
            .thenThrow(const FormBearingPagesLoadException('temp'));
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        // First call from the BlocProvider's initial load.
        verify(tree.pagesRepo.loadAll).called(1);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        verify(tree.pagesRepo.loadAll).called(1);
      });
    });

    group('success+empty state', () {
      testWidgets('renders the empty-state copy', (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll).thenAnswer((_) async => []);
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('No form-bearing pages yet'), findsOneWidget);
      });
    });

    group('success+rows state', () {
      final samplePages = [
        const FormBearingPage(
          ulid: '01HXSAMPLE0001',
          title: 'Bug reports',
          relativePath: 'Operations/Bug reports.md',
          formsRef: 'true',
        ),
        const FormBearingPage(
          ulid: '01HXSAMPLE0002',
          title: 'Customer signups',
          relativePath: 'CRM/Customer signups.md',
          formsRef: 'Customers.database.yaml',
        ),
      ];

      testWidgets('renders one row per page with title + relativePath',
          (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll)
            .thenAnswer((_) async => samplePages);
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        expect(find.text('Bug reports'), findsOneWidget);
        expect(find.text('Customer signups'), findsOneWidget);
        expect(find.text('Operations/Bug reports.md'), findsOneWidget);
        expect(find.text('CRM/Customer signups.md'), findsOneWidget);
      });

      testWidgets('renders the formsRef chip per row', (tester) async {
        final tree = pumpPane();
        when(tree.pagesRepo.loadAll)
            .thenAnswer((_) async => samplePages);
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        expect(find.text('true'), findsOneWidget);
        expect(find.text('Customers.database.yaml'), findsOneWidget);
      });
    });

    group('row tap → auth gate', () {
      final onePage = [
        const FormBearingPage(
          ulid: '01HXSAMPLE0001',
          title: 'Bug reports',
          relativePath: 'Operations/Bug reports.md',
          formsRef: 'true',
        ),
      ];

      testWidgets('unauthed tap surfaces a "Not logged in" toast', (tester) async {
        final tree = pumpPane(
          syncState: const SyncState(status: SyncStatus.initial),
        );
        when(tree.pagesRepo.loadAll).thenAnswer((_) async => onePage);
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bug reports'));
        await tester.pump();
        // Toast renders the warn copy from QuillToastHost.
        expect(find.text('Not logged in'), findsOneWidget);
        // No dialog should open — FormSubmissionsDialog renders an
        // AlertDialog only when reached past the auth gate.
        expect(find.byType(AlertDialog), findsNothing);
        // Repo is NOT invoked when auth gate trips.
        verifyNever(() => tree.formsRepo.listSubmissions(
              token: any(named: 'token'),
              ulid: any(named: 'ulid'),
            ));
      });

      testWidgets('authed tap opens the FormSubmissionsDialog', (tester) async {
        final tree = pumpPane(
          syncState: const SyncState(
            status: SyncStatus.success,
            token: 'jwt-test-token',
          ),
        );
        when(tree.pagesRepo.loadAll).thenAnswer((_) async => onePage);
        // Stub the submissions load to a resolvable empty list so the
        // dialog doesn't hang.
        when(() => tree.formsRepo.listSubmissions(
              token: any(named: 'token'),
              ulid: any(named: 'ulid'),
            )).thenAnswer((_) async => <FormSubmission>[]);
        await tester.pumpWidget(tree.widget);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bug reports'));
        await tester.pumpAndSettle();
        // The dialog renders into an AlertDialog/Dialog.
        expect(find.byType(Dialog), findsOneWidget);
      });
    });
  });
}
