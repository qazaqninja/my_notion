import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/util/throttle.dart';

void main() {
  group('Throttle (H2.5)', () {
    test('first call runs immediately', () {
      var count = 0;
      final now = DateTime(2026, 5, 17, 10);
      final t = Throttle<void>(const Duration(seconds: 5), now: () => now);
      t.run(() => count++);
      expect(count, 1);
    });

    test('second call inside the window is suppressed', () {
      var count = 0;
      var fake = DateTime(2026, 5, 17, 10);
      final t = Throttle<void>(const Duration(seconds: 5), now: () => fake);
      t.run(() => count++);
      fake = fake.add(const Duration(seconds: 2));
      t.run(() => count++);
      expect(count, 1);
    });

    test('second call after the window runs', () {
      var count = 0;
      var fake = DateTime(2026, 5, 17, 10);
      final t = Throttle<void>(const Duration(seconds: 5), now: () => fake);
      t.run(() => count++);
      fake = fake.add(const Duration(seconds: 6));
      t.run(() => count++);
      expect(count, 2);
    });

    test('rapid burst inside the window all suppressed except the first',
        () {
      var count = 0;
      final now = DateTime(2026, 5, 17, 10);
      final t = Throttle<void>(const Duration(seconds: 5), now: () => now);
      for (var i = 0; i < 20; i++) {
        t.run(() => count++);
      }
      expect(count, 1);
    });

    test('returns the value of the wrapped fn when run, null when suppressed',
        () {
      var fake = DateTime(2026, 5, 17, 10);
      final t = Throttle<int>(
        const Duration(seconds: 5),
        now: () => fake,
      );
      expect(t.run(() => 42), 42);
      fake = fake.add(const Duration(seconds: 1));
      expect(t.run(() => 99), isNull);
      fake = fake.add(const Duration(seconds: 5));
      expect(t.run(() => 7), 7);
    });

    test('reset() clears the last-fired stamp so the next call always runs',
        () {
      var count = 0;
      var fake = DateTime(2026, 5, 17, 10);
      final t = Throttle<void>(const Duration(seconds: 5), now: () => fake);
      t.run(() => count++);
      t.reset();
      fake = fake.add(const Duration(seconds: 1));
      t.run(() => count++);
      expect(count, 2);
    });
  });
}
