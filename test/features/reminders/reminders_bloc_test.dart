// RemindersBloc test (B4 slice 2 / TS-03).
//
// Drives the bloc through ScheduleReminder / CancelReminder /
// CancelAllReminders, verifying both the emitted state transitions and the
// recorded NotificationScheduler invocations.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/reminders/data/datasources/notification_scheduler.dart';
import 'package:my_notion/features/reminders/presentation/bloc/reminders_bloc.dart';
import 'package:my_notion/features/reminders/presentation/bloc/reminders_event.dart';
import 'package:my_notion/features/reminders/presentation/bloc/reminders_state.dart';

class _MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

void main() {
  late _MockNotificationScheduler scheduler;

  setUp(() {
    scheduler = _MockNotificationScheduler();
    when(
      () => scheduler.schedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        when: any(named: 'when'),
      ),
    ).thenAnswer((_) async {});
    when(() => scheduler.cancel(any())).thenAnswer((_) async {});
    when(scheduler.cancelAll).thenAnswer((_) async {});
  });

  group('RemindersBloc', () {
    blocTest<RemindersBloc, RemindersState>(
      'ScheduleReminder calls scheduler.schedule and adds ulid to state',
      build: () => RemindersBloc(scheduler: scheduler),
      act: (bloc) => bloc.add(
        ScheduleReminder(
          ulid: '01HABC',
          title: 'Read inbox',
          when: DateTime(2026, 5, 17),
        ),
      ),
      expect: () => [
        const RemindersState(scheduled: {'01HABC'}),
      ],
      verify: (_) {
        verify(
          () => scheduler.schedule(
            id: '01HABC'.hashCode,
            title: 'Read inbox',
            body: 'Reminder: Read inbox',
            when: DateTime(2026, 5, 17),
          ),
        ).called(1);
      },
    );

    blocTest<RemindersBloc, RemindersState>(
      'CancelReminder removes ulid from state and calls scheduler.cancel',
      build: () => RemindersBloc(scheduler: scheduler),
      seed: () => const RemindersState(scheduled: {'01HABC', '01HXYZ'}),
      act: (bloc) => bloc.add(const CancelReminder('01HABC')),
      expect: () => [
        const RemindersState(scheduled: {'01HXYZ'}),
      ],
      verify: (_) {
        verify(() => scheduler.cancel('01HABC'.hashCode)).called(1);
      },
    );

    blocTest<RemindersBloc, RemindersState>(
      'CancelReminder is a no-op when the ulid was not previously scheduled',
      build: () => RemindersBloc(scheduler: scheduler),
      act: (bloc) => bloc.add(const CancelReminder('01HABC')),
      expect: () => const <RemindersState>[],
      verify: (_) {
        verifyNever(() => scheduler.cancel(any()));
      },
    );

    blocTest<RemindersBloc, RemindersState>(
      'CancelAllReminders empties the set and calls scheduler.cancelAll',
      build: () => RemindersBloc(scheduler: scheduler),
      seed: () => const RemindersState(scheduled: {'01HABC', '01HXYZ'}),
      act: (bloc) => bloc.add(const CancelAllReminders()),
      expect: () => [const RemindersState()],
      verify: (_) {
        verify(scheduler.cancelAll).called(1);
      },
    );

    blocTest<RemindersBloc, RemindersState>(
      'scheduler failure still records the intent in state (best-effort UX)',
      build: () {
        when(
          () => scheduler.schedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            when: any(named: 'when'),
          ),
        ).thenThrow(StateError('platform missing'));
        return RemindersBloc(scheduler: scheduler);
      },
      act: (bloc) => bloc.add(
        ScheduleReminder(
          ulid: '01HABC',
          title: 'Read inbox',
          when: DateTime(2026, 5, 17),
        ),
      ),
      expect: () => [
        const RemindersState(scheduled: {'01HABC'}),
      ],
    );
  });
}
