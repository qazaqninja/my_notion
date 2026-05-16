// Smoke test for mockingjay (RULES.md TS-09).
//
// mockingjay's public API mocks Navigator (push / pop / replace) via
// `MockNavigator + MockNavigatorProvider`. For go_router specifically, the
// canonical pattern is to subclass `Mock` from mocktail (re-exported via
// mockingjay) and `implements GoRouter`. This file demonstrates both styles
// so future test authors have a reference.
//
// Once these pass, the architectural prerequisite for replacing hand-rolled
// router spies in widget tests with `MockNavigator.wrap(...)` and
// `_MockGoRouter` mocks is satisfied.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockingjay/mockingjay.dart';

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('mockingjay smoke (TS-09)', () {
    testWidgets('MockNavigator records push() calls', (tester) async {
      final navigator = MockNavigator();
      when(navigator.canPop).thenReturn(false);
      when(() => navigator.push<void>(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: MockNavigatorProvider(
            navigator: navigator,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                ),
                child: const Text('push me'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push me'));
      await tester.pump();

      verify(() => navigator.push<void>(any())).called(1);
    });

    test('GoRouter mocked via mocktail records go() and goNamed() calls', () {
      final router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
      when(
        () => router.goNamed(any(), pathParameters: any(named: 'pathParameters')),
      ).thenReturn(null);

      router.go('/destination');
      router.goNamed('editor', pathParameters: {'ulid': '01HABC'});

      verify(() => router.go('/destination')).called(1);
      verify(
        () => router.goNamed(
          'editor',
          pathParameters: any(named: 'pathParameters'),
        ),
      ).called(1);
    });
  });
}
