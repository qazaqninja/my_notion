import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/forms/domain/entities/form_submission.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';
import 'package:my_notion/features/forms/presentation/widgets/form_submissions_dialog.dart';

import '../../../helpers/test_theme.dart';

/// E51 — pure-presentational dialog tests. The repository call is
/// abstracted behind `load: () => Future<List<FormSubmission>>` so we
/// can inject success / failure / empty without standing up the HTTP
/// stack.
void main() {
  const ulid = '01HX0V0000000000000000000A';

  testWidgets('Renders ULID header + each submission as a tile',
      (tester) async {
    final submissions = [
      FormSubmission(
        id: 'sub-1',
        pageUlid: ulid,
        fields: const {'name': 'Pat', 'email': 'p@x'},
        createdAt: DateTime.utc(2026, 5, 17, 12),
        sourceIp: '203.0.113.42',
      ),
      FormSubmission(
        id: 'sub-2',
        pageUlid: ulid,
        fields: const {'name': 'Jo'},
        createdAt: DateTime.utc(2026, 5, 17, 13),
      ),
    ];
    await tester.pumpWidget(testApp(FormSubmissionsDialog(
      ulid: ulid,
      load: () async => submissions,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Form submissions'), findsOneWidget);
    expect(find.text(ulid), findsOneWidget);
    expect(find.textContaining('Pat'), findsOneWidget);
    expect(find.textContaining('Jo'), findsOneWidget);
    expect(find.textContaining('from 203.0.113.42'), findsOneWidget);
  });

  testWidgets('Empty list renders the "No submissions yet." placeholder',
      (tester) async {
    await tester.pumpWidget(testApp(FormSubmissionsDialog(
      ulid: ulid,
      load: () async => const <FormSubmission>[],
    )));
    await tester.pumpAndSettle();
    expect(find.text('No submissions yet.'), findsOneWidget);
  });

  testWidgets('FormsNotOwnerException → owner-not-owner copy + Retry button',
      (tester) async {
    await tester.pumpWidget(testApp(FormSubmissionsDialog(
      ulid: ulid,
      load: () async => throw const FormsNotOwnerException(),
    )));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not yours'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('FormsAuthException → session-expired copy', (tester) async {
    await tester.pumpWidget(testApp(FormSubmissionsDialog(
      ulid: ulid,
      load: () async => throw const FormsAuthException(),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Session expired'), findsOneWidget);
  });

  testWidgets('Retry re-invokes the load callback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(testApp(FormSubmissionsDialog(
      ulid: ulid,
      load: () async {
        calls++;
        if (calls == 1) throw const FormsNetworkException('boom');
        return const <FormSubmission>[];
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network: boom'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No submissions yet.'), findsOneWidget);
  });
}
