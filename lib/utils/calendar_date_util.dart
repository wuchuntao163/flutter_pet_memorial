/// 日历日换算：统一按本地时区的年月日计算，避免 iOS 解析 UTC 后与今天混算差一天。
class CalendarDateUtil {
  CalendarDateUtil._();

  static DateTime localDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? tryParseLocalDate(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return null;
    return localDateOnly(parsed);
  }

  static int daysBetween(DateTime from, DateTime to) {
    return localDateOnly(to).difference(localDateOnly(from)).inDays;
  }
}
