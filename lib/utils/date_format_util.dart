import '../services/language_service.dart';

/// 按当前语言格式化公历 / 农历日期（英文不用简写）
class DateFormatUtil {
  DateFormatUtil._();

  static bool get isEnglish => LanguageService.instance.fontName == 'en';

  static const _solarMonthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String solarMonthName(int month) {
    assert(month >= 1 && month <= 12);
    if (isEnglish) return _solarMonthsEn[month - 1];
    return '$month月';
  }

  /// 公历完整日期，如 January 15, 2024 / 2024年1月15日
  static String formatSolarYmd({
    required int year,
    required int month,
    required int day,
  }) {
    if (isEnglish) {
      return '${solarMonthName(month)} $day, $year';
    }
    return '$year年$month月$day日';
  }

  static String formatSolarYear(int year) {
    if (isEnglish) return '$year';
    return '$year年';
  }

  /// 公历月日，如 January 15 / 1月15日
  static String formatSolarMonthDay({
    required int month,
    required int day,
  }) {
    if (isEnglish) {
      return '${solarMonthName(month)} $day';
    }
    return '$month月$day日';
  }

  /// 详情页月份主标题：January / JAN（中文保持原简写）
  static String solarMonthTitle(int month) {
    if (isEnglish) return solarMonthName(month);
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[month - 1];
  }

  /// 详情页农历月份主标题：Month 4 / Leap Month 4 / LM4
  static String lunarMonthTitle({
    required int month,
    bool isLeapMonth = false,
  }) {
    if (isEnglish) {
      return isLeapMonth ? 'Leap Month $month' : 'Month $month';
    }
    if (isLeapMonth) return 'LLM$month';
    return 'LM$month';
  }

  /// 农历完整日期
  static String formatLunarYmd({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
    required String Function() chineseFormatter,
  }) {
    if (isEnglish) {
      final monthPart =
          isLeapMonth ? 'Leap Month $month' : 'Month $month';
      return 'Lunar $year, $monthPart, Day $day';
    }
    return chineseFormatter();
  }

  /// 网格卡片农历年份行
  static String formatLunarYearLine({
    required int year,
    required String Function() chineseFormatter,
  }) {
    if (isEnglish) return 'Lunar $year';
    return chineseFormatter();
  }

  /// 网格卡片农历月日行
  static String formatLunarMonthDayLine({
    required int month,
    required int day,
    bool isLeapMonth = false,
    required String Function() chineseFormatter,
  }) {
    if (isEnglish) {
      final monthPart =
          isLeapMonth ? 'Leap Month $month' : 'Month $month';
      return '$monthPart, Day $day';
    }
    return chineseFormatter();
  }

  /// 选择器：年份
  static String pickerYearLabel(int year) {
    if (isEnglish) return '$year';
    return '$year年';
  }

  /// 选择器：月份（公历）
  static String pickerSolarMonthLabel(int month) => solarMonthName(month);

  /// 选择器：日
  static String pickerDayLabel(int day) {
    if (isEnglish) return '$day';
    return '$day日';
  }

  /// 农历选择器月份（英文闰月用短标签 Leap M4，避免滚轮列宽不够）
  static String pickerLunarMonthLabel({
    required int month,
    bool isLeapMonth = false,
  }) {
    if (isEnglish) {
      return isLeapMonth ? 'Leap M$month' : 'Month $month';
    }
    return lunarMonthTitle(month: month, isLeapMonth: isLeapMonth);
  }
}
