import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/reminder_date.dart';

void main() {
  group('isoDate', () {
    test('formats month + day with zero padding', () {
      expect(isoDate(DateTime(2026, 5, 7)), '2026-05-07');
    });

    test('formats double-digit month + day without extra padding', () {
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('pads year to 4 digits', () {
      expect(isoDate(DateTime(42, 1, 2)), '0042-01-02');
    });

    test('ignores time-of-day components', () {
      // Reminders are date-only (YYYY-MM-DD); the picker returns a
      // DateTime at midnight but we should still serialise just the
      // calendar date.
      expect(isoDate(DateTime(2026, 5, 7, 13, 45)), '2026-05-07');
    });
  });

  group('relativeReminderLabel', () {
    final now = DateTime(2026, 5, 7);

    test('same day → "today"', () {
      expect(
        relativeReminderLabel(picked: DateTime(2026, 5, 7), now: now),
        'today',
      );
    });

    test('+1 day → "tomorrow"', () {
      expect(
        relativeReminderLabel(picked: DateTime(2026, 5, 8), now: now),
        'tomorrow',
      );
    });

    test('+N days → "in N days"', () {
      expect(
        relativeReminderLabel(picked: DateTime(2026, 5, 10), now: now),
        'in 3 days',
      );
    });

    test('-1 day → "1 day ago"', () {
      expect(
        relativeReminderLabel(picked: DateTime(2026, 5, 6), now: now),
        '1 day ago',
      );
    });

    test('-N days → "N days ago"', () {
      expect(
        relativeReminderLabel(picked: DateTime(2026, 5, 1), now: now),
        '6 days ago',
      );
    });

    test('ignores time-of-day on both sides', () {
      // A picked DateTime at 23:59 and now() at 00:01 the next morning
      // should still report "tomorrow" rather than "today" — the
      // comparison is on calendar date.
      expect(
        relativeReminderLabel(
          picked: DateTime(2026, 5, 8, 23, 59),
          now: DateTime(2026, 5, 7, 0, 1),
        ),
        'tomorrow',
      );
    });
  });

  group('snoozeBaseFor', () {
    final today = DateTime(2026, 5, 7);

    test('returns start-of-today when existing is null', () {
      expect(snoozeBaseFor(existing: null, today: today), today);
    });

    test('returns start-of-today when existing is strictly in the past', () {
      expect(
        snoozeBaseFor(existing: DateTime(2025, 12, 1), today: today),
        today,
      );
    });

    test('returns existing day when it equals today', () {
      expect(
        snoozeBaseFor(existing: DateTime(2026, 5, 7), today: today),
        DateTime(2026, 5, 7),
      );
    });

    test('returns existing day when it is in the future', () {
      expect(
        snoozeBaseFor(existing: DateTime(2026, 6, 1), today: today),
        DateTime(2026, 6, 1),
      );
    });

    test('strips time-of-day from existing future day', () {
      // The legacy helper called DateTime(year, month, day) on the
      // parsed result; ours should too so the resulting iso line up.
      expect(
        snoozeBaseFor(
          existing: DateTime(2026, 6, 1, 23, 45),
          today: today,
        ),
        DateTime(2026, 6, 1),
      );
    });

    test('strips time-of-day from today when existing is null', () {
      expect(
        snoozeBaseFor(existing: null, today: DateTime(2026, 5, 7, 13, 30)),
        DateTime(2026, 5, 7),
      );
    });
  });
}
