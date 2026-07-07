import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/memorial_day.dart';
import 'lunar_calendar_util.dart';

/// 根据纪念日数据计算下次本地通知响铃时间（默认当天 9:00）
class MemorialReminderSchedule {
  MemorialReminderSchedule._();

  static const reminderHour = 9;
  static const reminderMinute = 0;

  static DateTime? nextTrigger(MemorialDay day, {DateTime? from}) {
    if (!day.hasReminder) return null;
    final now = from ?? DateTime.now();
    final anchorTrigger = _atTime(day.listDisplayDate);

    // 所有重复模式均从所选日期当天 9:00 起才开始推送
    if (anchorTrigger.isAfter(now)) {
      return anchorTrigger;
    }

    switch (day.repeatFrequency) {
      case RepeatFrequency.none:
        return null;
      case RepeatFrequency.daily:
        return _nextDaily(now);
      case RepeatFrequency.weekly:
        return _nextWeekly(day, now);
      case RepeatFrequency.monthly:
        return _nextMonthly(day, now);
      case RepeatFrequency.yearly:
        return _nextYearly(day, now);
    }
  }

  static DateTime _nextDaily(DateTime now) {
    var trigger = _atTime(DateTime(now.year, now.month, now.day));
    if (!trigger.isAfter(now)) {
      trigger = trigger.add(const Duration(days: 1));
    }
    return trigger;
  }

  static DateTime _nextWeekly(MemorialDay day, DateTime now) {
    final weekday = day.listDisplayDate.weekday;
    var cursor = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 8; i++) {
      final trigger = _atTime(cursor);
      if (cursor.weekday == weekday && trigger.isAfter(now)) {
        return trigger;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return _atTime(cursor);
  }

  static DateTime _nextMonthly(MemorialDay day, DateTime now) {
    final targetDay = day.listDisplayDate.day;
    var year = now.year;
    var month = now.month;

    for (var i = 0; i < 24; i++) {
      final dayInMonth = _clampDayOfMonth(year, month, targetDay);
      final trigger = _atTime(DateTime(year, month, dayInMonth));
      if (trigger.isAfter(now)) return trigger;

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return _atTime(DateTime(year, month, _clampDayOfMonth(year, month, targetDay)));
  }

  static DateTime? _nextYearly(MemorialDay day, DateTime now) {
    if (day.calendarType == CalendarType.lunar) {
      return _nextYearlyLunar(day, now);
    }
    final anchor = day.listDisplayDate;
    var year = now.year;
    for (var i = 0; i < 15; i++) {
      final d = _clampDayOfMonth(year, anchor.month, anchor.day);
      final trigger = _atTime(DateTime(year, anchor.month, d));
      if (trigger.isAfter(now)) return trigger;
      year++;
    }
    return null;
  }

  static DateTime? _nextYearlyLunar(MemorialDay day, DateTime now) {
    final startYear = day.date.year > now.year ? day.date.year : now.year;
    for (var y = startYear; y <= startYear + 15; y++) {
      final solar = _lunarSolarOrNull(
            y,
            day.date.month,
            day.date.day,
            day.isLunarLeapMonth,
          ) ??
          _lunarSolarOrNull(y, day.date.month, day.date.day, false);
      if (solar == null) continue;
      final trigger = _atTime(solar);
      if (trigger.isAfter(now)) return trigger;
    }
    return null;
  }

  static DateTime? _lunarSolarOrNull(
    int year,
    int month,
    int day,
    bool isLeapMonth,
  ) {
    try {
      return LunarCalendarUtil.lunarToSolar(
        year: year,
        month: month,
        day: day,
        isLeapMonth: isLeapMonth,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _atTime(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        reminderHour,
        reminderMinute,
      );

  static int _clampDayOfMonth(int year, int month, int day) {
    final maxDay = DateTime(year, month + 1, 0).day;
    return day > maxDay ? maxDay : day;
  }

  static DateTimeComponents? matchComponents(MemorialDay day) {
    switch (day.repeatFrequency) {
      case RepeatFrequency.daily:
        return DateTimeComponents.time;
      case RepeatFrequency.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepeatFrequency.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RepeatFrequency.yearly:
        if (day.calendarType == CalendarType.solar) {
          return DateTimeComponents.dateAndTime;
        }
        return null;
      case RepeatFrequency.none:
        return null;
    }
  }
}