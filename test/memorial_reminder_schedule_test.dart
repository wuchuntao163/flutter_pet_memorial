import 'package:flutter_pet_memorial/models/memorial_day.dart';
import 'package:flutter_pet_memorial/utils/memorial_reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

MemorialDay _day({
  required DateTime date,
  RepeatFrequency repeat = RepeatFrequency.daily,
}) {
  return MemorialDay(
    id: 'test',
    title: 'Test',
    type: MemorialType.custom,
    date: date,
    repeatFrequency: repeat,
    hasReminder: true,
  );
}

void main() {
  group('MemorialReminderSchedule.nextTrigger', () {
    test('daily waits until anchor date before repeating', () {
      final day = _day(
        date: DateTime(2026, 8, 1),
        repeat: RepeatFrequency.daily,
      );
      final now = DateTime(2026, 7, 7, 10, 0);

      final next = MemorialReminderSchedule.nextTrigger(day, from: now);

      expect(next, DateTime(2026, 8, 1, 9, 0));
    });

    test('weekly waits until anchor date before repeating', () {
      // 2026-08-01 is Saturday
      final day = _day(
        date: DateTime(2026, 8, 1),
        repeat: RepeatFrequency.weekly,
      );
      final now = DateTime(2026, 7, 7, 10, 0); // Tuesday

      final next = MemorialReminderSchedule.nextTrigger(day, from: now);

      expect(next, DateTime(2026, 8, 1, 9, 0));
    });

    test('monthly waits until anchor date before repeating', () {
      final day = _day(
        date: DateTime(2026, 8, 15),
        repeat: RepeatFrequency.monthly,
      );
      final now = DateTime(2026, 7, 7, 10, 0);

      final next = MemorialReminderSchedule.nextTrigger(day, from: now);

      expect(next, DateTime(2026, 8, 15, 9, 0));
    });

    test('yearly waits until anchor date before repeating', () {
      final day = _day(
        date: DateTime(2026, 12, 25),
        repeat: RepeatFrequency.yearly,
      );
      final now = DateTime(2026, 7, 7, 10, 0);

      final next = MemorialReminderSchedule.nextTrigger(day, from: now);

      expect(next, DateTime(2026, 12, 25, 9, 0));
    });

    test('none only fires once on anchor date', () {
      final day = _day(
        date: DateTime(2026, 8, 1),
        repeat: RepeatFrequency.none,
      );

      expect(
        MemorialReminderSchedule.nextTrigger(
          day,
          from: DateTime(2026, 7, 7, 10, 0),
        ),
        DateTime(2026, 8, 1, 9, 0),
      );
      expect(
        MemorialReminderSchedule.nextTrigger(
          day,
          from: DateTime(2026, 8, 2, 10, 0),
        ),
        isNull,
      );
    });

    test('daily repeats after anchor date has passed', () {
      final day = _day(
        date: DateTime(2026, 8, 1),
        repeat: RepeatFrequency.daily,
      );
      final now = DateTime(2026, 8, 2, 8, 0);

      final next = MemorialReminderSchedule.nextTrigger(day, from: now);

      expect(next, DateTime(2026, 8, 2, 9, 0));
    });
  });
}
