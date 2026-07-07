import 'package:flutter_pet_memorial/models/memorial_day.dart';
import 'package:flutter_pet_memorial/utils/calendar_date_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDateUtil', () {
    test('normalizes UTC timestamp to local calendar day', () {
      final parsed = DateTime.parse('2026-07-08T16:00:00.000Z');
      expect(
        CalendarDateUtil.localDateOnly(parsed),
        DateTime(2026, 7, 9),
      );
    });

    test('daysBetween uses local calendar days only', () {
      final today = DateTime(2026, 7, 7);
      final anchor = DateTime.parse('2026-07-08T16:00:00.000Z');
      expect(CalendarDateUtil.daysBetween(today, anchor), 2);
    });
  });

  group('MemorialDay.displayDayCount', () {
    MemorialDay dayFromApi(String date) {
      return MemorialDay.fromApi({
        'id': 1,
        'name': 'Test',
        'date': date,
        'date_type': 1,
        'repeat_frequency': 0,
      });
    }

    test('UTC API date counts down to the local target day', () {
      final day = dayFromApi('2026-07-08T16:00:00.000Z');
      expect(day.listDisplayDate, DateTime(2026, 7, 9));

      final today = DateTime(2026, 7, 7);
      final anchor = CalendarDateUtil.localDateOnly(day.listDisplayDate);
      expect(anchor.difference(CalendarDateUtil.localDateOnly(today)).inDays, 2);
    });
  });
}
