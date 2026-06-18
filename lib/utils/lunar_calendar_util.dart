import 'package:lunar/lunar.dart';

import 'date_format_util.dart';

/// 公历 / 农历换算（基于 lunar 库）
class LunarCalendarUtil {
  LunarCalendarUtil._();

  static int _lunarMonthArg(int month, bool isLeapMonth) =>
      isLeapMonth ? -month : month;

  /// 农历年月日 → 公历 DateTime（仅日期）
  static DateTime lunarToSolar({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) {
    final solar = Lunar.fromYmd(
      year,
      _lunarMonthArg(month, isLeapMonth),
      day,
    ).getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  }

  /// 公历 → 农历年月日
  static ({
    int year,
    int month,
    int day,
    bool isLeapMonth,
  }) solarToLunar(DateTime solar) {
    final lunar = Solar.fromYmd(solar.year, solar.month, solar.day).getLunar();
    final rawMonth = lunar.getMonth();
    return (
      year: lunar.getYear(),
      month: rawMonth.abs(),
      day: lunar.getDay(),
      isLeapMonth: rawMonth < 0,
    );
  }

  static Lunar _lunar({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) =>
      Lunar.fromYmd(year, _lunarMonthArg(month, isLeapMonth), day);

  /// 网格卡片日期上行，如：农历二〇二二年
  static String formatLunarYearLine({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) {
    final lunar = _lunar(
      year: year,
      month: month,
      day: day,
      isLeapMonth: isLeapMonth,
    );
    return DateFormatUtil.formatLunarYearLine(
      year: lunar.getYear(),
      chineseFormatter: () => '农历${lunar.getYearInChinese()}年',
    );
  }

  /// 网格卡片日期下行，如：2月12日 / 闰四月初五
  static String formatLunarMonthDayLine({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) {
    final lunar = _lunar(
      year: year,
      month: month,
      day: day,
      isLeapMonth: isLeapMonth,
    );
    final leap = isLeapMonth ? '闰' : '';
    return DateFormatUtil.formatLunarMonthDayLine(
      month: month,
      day: day,
      isLeapMonth: isLeapMonth,
      chineseFormatter: () =>
          '$leap${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
    );
  }

  /// 如：农历2024年正月初五
  static String formatLunar({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) {
    final lunar = _lunar(
      year: year,
      month: month,
      day: day,
      isLeapMonth: isLeapMonth,
    );
    final leap = isLeapMonth ? '闰' : '';
    return DateFormatUtil.formatLunarYmd(
      year: lunar.getYear(),
      month: month,
      day: day,
      isLeapMonth: isLeapMonth,
      chineseFormatter: () =>
          '农历${lunar.getYearInChinese()}年$leap${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
    );
  }

  /// 详情页农历月份主标题
  static String monthAbbr({
    required int year,
    required int month,
    bool isLeapMonth = false,
  }) {
    return DateFormatUtil.lunarMonthTitle(
      month: month,
      isLeapMonth: isLeapMonth,
    );
  }

  /// 选择器、完整文案等用的中文月名
  static String monthLabel({
    required int year,
    required int month,
    bool isLeapMonth = false,
  }) {
    if (DateFormatUtil.isEnglish) {
      return DateFormatUtil.lunarMonthTitle(
        month: month,
        isLeapMonth: isLeapMonth,
      );
    }
    final lunar = _lunar(year: year, month: month, day: 1, isLeapMonth: isLeapMonth);
    final leap = isLeapMonth ? '闰' : '';
    return '$leap${lunar.getMonthInChinese()}';
  }

  static int daysInLunarMonth({
    required int year,
    required int month,
    bool isLeapMonth = false,
  }) {
    final m = LunarYear.fromYear(year).getMonth(_lunarMonthArg(month, isLeapMonth));
    return m?.getDayCount() ?? 30;
  }
}

/// 农历日期选择结果
class LunarDateSelection {
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  const LunarDateSelection({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  DateTime toDateTime() => DateTime(year, month, day);
}
