// Smoke test for the NotificationScheduler abstraction (B4 slice 1).
//
// We only verify the abstract contract here. Driving the actual
// flutter_local_notifications plugin requires a real platform channel and
// is out of scope for a unit test. The integration test (deferred) will
// cover the live OS notification path.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/reminders/data/datasources/notification_scheduler.dart';

class _MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

void main() {
  group('NotificationScheduler abstraction (B4)', () {
    late NotificationScheduler scheduler;

    setUp(() {
      scheduler = _MockNotificationScheduler();
      when(scheduler.init).thenAnswer((_) async {});
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

    test('init/schedule/cancel/cancelAll all exposed and stubbable', () async {
      await scheduler.init();
      await scheduler.schedule(
        id: 42,
        title: 'Page reminder',
        body: 'Read inbox',
        when: DateTime(2026, 5, 17),
      );
      await scheduler.cancel(42);
      await scheduler.cancelAll();

      verify(scheduler.init).called(1);
      verify(
        () => scheduler.schedule(
          id: 42,
          title: 'Page reminder',
          body: 'Read inbox',
          when: DateTime(2026, 5, 17),
        ),
      ).called(1);
      verify(() => scheduler.cancel(42)).called(1);
      verify(scheduler.cancelAll).called(1);
    });
  });
}
