import '../l10n/tr.dart';
import '../utils/date_format_util.dart';
import '../utils/lunar_calendar_util.dart';

enum MemorialType { birthday, event, festival, work, life, custom }

enum CalendarType { solar, lunar }

enum RepeatFrequency { none, daily, weekly, monthly, yearly }

/// 详情页天数展示格式（点击切换）
enum DayCountDisplayMode {
  days,
  weeksDays,
  monthsDays,
  yearsMonthsDays;

  DayCountDisplayMode get next {
    switch (this) {
      case DayCountDisplayMode.days:
        return DayCountDisplayMode.weeksDays;
      case DayCountDisplayMode.weeksDays:
        return DayCountDisplayMode.monthsDays;
      case DayCountDisplayMode.monthsDays:
        return DayCountDisplayMode.yearsMonthsDays;
      case DayCountDisplayMode.yearsMonthsDays:
        return DayCountDisplayMode.days;
    }
  }
}

class _DateDiffParts {
  final int years;
  final int months;
  final int days;

  const _DateDiffParts(this.years, this.months, this.days);
}

/// 天数展示片段：数字或单位（年/月/周/天）
class DayCountDisplaySegment {
  final int? number;
  final String? unit;

  const DayCountDisplaySegment.number(this.number) : unit = null;
  const DayCountDisplaySegment.unit(this.unit) : number = null;

  bool get isNumber => number != null;
}

List<DayCountDisplaySegment> parseDayCountSegments(String formatted) {
  // 兼容旧数据；新展示请用 [MemorialDay.buildDayCountSegments]
  final regex = RegExp(r'(\d+)|([^\d]+)');
  return [
    for (final match in regex.allMatches(formatted))
      if (match.group(1) != null)
        DayCountDisplaySegment.number(int.parse(match.group(1)!))
      else
        DayCountDisplaySegment.unit(match.group(2)!),
  ];
}

extension RepeatFrequencyLabel on RepeatFrequency {
  String get label {
    switch (this) {
      case RepeatFrequency.none:
        return tr('repeat.none');
      case RepeatFrequency.daily:
        return tr('repeat.daily');
      case RepeatFrequency.weekly:
        return tr('repeat.weekly');
      case RepeatFrequency.monthly:
        return tr('repeat.monthly');
      case RepeatFrequency.yearly:
        return tr('repeat.yearly');
    }
  }
}

class MemorialDay {
  final String id;
  final String title;
  final MemorialType type;
  final DateTime date;
  final CalendarType calendarType;
  /// 农历闰月（仅 calendarType 为 lunar 时有效）
  final bool isLunarLeapMonth;
  final RepeatFrequency repeatFrequency;
  final bool isPinned;
  final bool hasReminder;
  /// 数字样式 ID：`normal` 为普通数字，其余来自 getFontStyles
  final String fontStyleId;
  final String backgroundTab;
  final String backgroundStyleId;
  final DayCountDisplayMode dayCountDisplayMode;
  /// [MemorialType.custom] 时用户输入的类型名称
  final String? customTypeName;
  final int? typeId;
  /// 接口 type.bg_color，如 #FF5733
  final String? typeBgColorHex;

  const MemorialDay({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.typeId,
    this.calendarType = CalendarType.solar,
    this.isLunarLeapMonth = false,
    this.repeatFrequency = RepeatFrequency.yearly,
    this.isPinned = false,
    this.hasReminder = false,
    this.fontStyleId = 'normal',
    this.backgroundTab = '简约',
    this.backgroundStyleId = '',
    this.dayCountDisplayMode = DayCountDisplayMode.days,
    this.customTypeName,
    this.typeBgColorHex,
  });

  MemorialDay copyWith({
    String? id,
    String? title,
    MemorialType? type,
    DateTime? date,
    CalendarType? calendarType,
    bool? isLunarLeapMonth,
    RepeatFrequency? repeatFrequency,
    bool? isPinned,
    bool? hasReminder,
    String? fontStyleId,
    String? backgroundTab,
    String? backgroundStyleId,
    DayCountDisplayMode? dayCountDisplayMode,
    String? customTypeName,
    int? typeId,
    String? typeBgColorHex,
  }) {
    return MemorialDay(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      date: date ?? this.date,
      typeId: typeId ?? this.typeId,
      calendarType: calendarType ?? this.calendarType,
      isLunarLeapMonth: isLunarLeapMonth ?? this.isLunarLeapMonth,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      isPinned: isPinned ?? this.isPinned,
      hasReminder: hasReminder ?? this.hasReminder,
      fontStyleId: fontStyleId ?? this.fontStyleId,
      backgroundTab: backgroundTab ?? this.backgroundTab,
      backgroundStyleId: backgroundStyleId ?? this.backgroundStyleId,
      dayCountDisplayMode:
          dayCountDisplayMode ?? this.dayCountDisplayMode,
      customTypeName: customTypeName ?? this.customTypeName,
      typeBgColorHex: typeBgColorHex ?? this.typeBgColorHex,
    );
  }

  /// 展示用类型名：接口/缓存 [customTypeName] 原样展示，仅本地枚举兜底走语言包
  String get typeLabel {
    final fromApi = customTypeName?.trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    switch (type) {
      case MemorialType.birthday:
        return tr('memorial_type.birthday');
      case MemorialType.event:
        return tr('memorial_type.event');
      case MemorialType.festival:
        return tr('memorial_type.festival');
      case MemorialType.work:
        return tr('memorial_type.work');
      case MemorialType.life:
        return tr('memorial_type.life');
      case MemorialType.custom:
        return tr('memorial_type.custom');
    }
  }

  /// 详情页日期区块标题
  String get dateSectionTitle {
    switch (type) {
      case MemorialType.birthday:
        return tr('memorial_type.birth_section');
      case MemorialType.festival:
        return tr('memorial_type.festival_section');
      case MemorialType.event:
        return tr('memorial_type.event_section');
      default:
        return tr('memorial_type.default_section');
    }
  }

  /// 列表与倒数日计算用公历日期（农历会先换算成公历）
  DateTime get listDisplayDate {
    if (calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.lunarToSolar(
        year: date.year,
        month: date.month,
        day: date.day,
        isLeapMonth: isLunarLeapMonth,
      );
    }
    return DateTime(date.year, date.month, date.day);
  }

  String get monthAbbr {
    if (calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.monthAbbr(
        year: date.year,
        month: date.month,
        isLeapMonth: isLunarLeapMonth,
      );
    }
    return DateFormatUtil.solarMonthTitle(listDisplayDate.month);
  }

  /// 列表卡片日期前缀（公历 JAN15，农历 LM1 15）
  String get cardDateLabel => calendarType == CalendarType.lunar
      ? '$monthAbbr $displayDayNumber'
      : '$monthAbbr$displayDayNumber';

  /// 卡片/详情展示用「日」
  int get displayDayNumber =>
      calendarType == CalendarType.lunar ? date.day : listDisplayDate.day;

  static const _weekdayKeys = [
    '',
    'weekday.mon',
    'weekday.tue',
    'weekday.wed',
    'weekday.thu',
    'weekday.fri',
    'weekday.sat',
    'weekday.sun',
  ];

  String get weekdayLabel =>
      tr(_weekdayKeys[listDisplayDate.weekday]);

  /// 列表卡片用周几（跟随换算后的公历日）
  String get listWeekdayLabel => weekdayLabel;

  String get listStatusLabel =>
      isPast ? tr('memorial_status.past') : tr('memorial_status.upcoming');

  String get formattedDate {
    if (calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.formatLunar(
        year: date.year,
        month: date.month,
        day: date.day,
        isLeapMonth: isLunarLeapMonth,
      );
    }
    return DateFormatUtil.formatSolarYmd(
      year: date.year,
      month: date.month,
      day: date.day,
    );
  }

  String get formattedDateWithWeekday => '$formattedDate $weekdayLabel';

  /// 展示用天数（农历会先换成公历再算间隔）
  int get displayDayCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchor = listDisplayDate;
    if (anchor.isBefore(today)) {
      return today.difference(anchor).inDays;
    }
    return anchor.difference(today).inDays;
  }

  String get statusLabel => isPast
      ? tr('memorial_status.past_long')
      : tr('memorial_status.upcoming_long');

  /// 首页网格卡片标题后缀
  String get gridStatusSuffix => isPast
      ? tr('memorial_status.past_grid')
      : tr('memorial_status.upcoming_grid');

  int get daysFromNow => displayDayCount;

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return listDisplayDate.isBefore(today);
  }

  _DateDiffParts get _displayDateDiff {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final anchor = listDisplayDate;
    final start = anchor.isBefore(today) ? anchor : today;
    final end = anchor.isBefore(today) ? today : anchor;
    return _calendarDiff(start, end);
  }

  static _DateDiffParts _calendarDiff(DateTime start, DateTime end) {
    var years = end.year - start.year;
    var months = end.month - start.month;
    var days = end.day - start.day;

    if (days < 0) {
      months -= 1;
      days += DateTime(end.year, end.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    return _DateDiffParts(years, months, days);
  }

  /// 详情页当前格式下的天数字符串（含「天」等单位）
  String get formattedDayCount => formatDayCount(dayCountDisplayMode);

  /// 当前天数下，各展示格式去重后仍有效的模式（文案相同只保留一种）
  List<DayCountDisplayMode> get availableDayCountDisplayModes {
    final seen = <String>{};
    final modes = <DayCountDisplayMode>[];
    for (final mode in DayCountDisplayMode.values) {
      if (seen.add(formatDayCount(mode))) {
        modes.add(mode);
      }
    }
    return modes;
  }

  /// 是否还能点击切换天数单位展示
  bool get canCycleDayCountDisplayMode =>
      availableDayCountDisplayModes.length > 1;

  /// 下一个可切换的展示模式；无可切换时返回 null
  DayCountDisplayMode? get nextDayCountDisplayMode {
    final modes = availableDayCountDisplayModes;
    if (modes.length <= 1) return null;

    var index = modes.indexOf(dayCountDisplayMode);
    if (index < 0) {
      final current = formattedDayCount;
      index = modes.indexWhere((m) => formatDayCount(m) == current);
      if (index < 0) return modes.first;
    }
    return modes[(index + 1) % modes.length];
  }

  /// 数字样式：按片段拆分（单位走语言包）
  List<DayCountDisplaySegment> get dayCountDisplaySegments =>
      buildDayCountSegments(dayCountDisplayMode);

  /// 数字样式弹窗预览：所有数字连写，如 25周1天 → 251
  int get digitalDisplayNumber {
    final digits = formattedDayCount.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return displayDayCount;
    return int.parse(digits);
  }

  String formatDayCount(DayCountDisplayMode mode) =>
      _joinSegments(buildDayCountSegments(mode));

  List<DayCountDisplaySegment> buildDayCountSegments(
    DayCountDisplayMode mode,
  ) {
    final day = tr('common.unit_day');
    final week = tr('common.unit_week');
    final month = tr('common.unit_month');
    final year = tr('common.unit_year');

    switch (mode) {
      case DayCountDisplayMode.days:
        return [
          DayCountDisplaySegment.number(displayDayCount),
          DayCountDisplaySegment.unit(day),
        ];
      case DayCountDisplayMode.weeksDays:
        final weeks = displayDayCount ~/ 7;
        final days = displayDayCount % 7;
        if (weeks == 0) {
          return [
            DayCountDisplaySegment.number(days),
            DayCountDisplaySegment.unit(day),
          ];
        }
        if (days == 0) {
          return [
            DayCountDisplaySegment.number(weeks),
            DayCountDisplaySegment.unit(week),
          ];
        }
        return [
          DayCountDisplaySegment.number(weeks),
          DayCountDisplaySegment.unit(week),
          DayCountDisplaySegment.number(days),
          DayCountDisplaySegment.unit(day),
        ];
      case DayCountDisplayMode.monthsDays:
        return _monthsDaysSegments(_displayDateDiff, month, day);
      case DayCountDisplayMode.yearsMonthsDays:
        return _yearsMonthsDaysSegments(_displayDateDiff, year, month, day);
    }
  }

  static List<DayCountDisplaySegment> _monthsDaysSegments(
    _DateDiffParts diff,
    String monthUnit,
    String dayUnit,
  ) {
    final totalMonths = diff.years * 12 + diff.months;
    if (totalMonths == 0) {
      return [
        DayCountDisplaySegment.number(diff.days),
        DayCountDisplaySegment.unit(dayUnit),
      ];
    }
    if (diff.days == 0) {
      return [
        DayCountDisplaySegment.number(totalMonths),
        DayCountDisplaySegment.unit(monthUnit),
      ];
    }
    return [
      DayCountDisplaySegment.number(totalMonths),
      DayCountDisplaySegment.unit(monthUnit),
      DayCountDisplaySegment.number(diff.days),
      DayCountDisplaySegment.unit(dayUnit),
    ];
  }

  static List<DayCountDisplaySegment> _yearsMonthsDaysSegments(
    _DateDiffParts diff,
    String yearUnit,
    String monthUnit,
    String dayUnit,
  ) {
    final segments = <DayCountDisplaySegment>[];
    if (diff.years > 0) {
      segments
        ..add(DayCountDisplaySegment.number(diff.years))
        ..add(DayCountDisplaySegment.unit(yearUnit));
    }
    if (diff.months > 0) {
      segments
        ..add(DayCountDisplaySegment.number(diff.months))
        ..add(DayCountDisplaySegment.unit(monthUnit));
    }
    if (diff.days > 0 || segments.isEmpty) {
      segments
        ..add(DayCountDisplaySegment.number(diff.days))
        ..add(DayCountDisplaySegment.unit(dayUnit));
    }
    return segments;
  }

  static String _joinSegments(List<DayCountDisplaySegment> segments) {
    final buffer = StringBuffer();
    for (final s in segments) {
      if (s.isNumber) {
        buffer.write(s.number);
      } else {
        buffer.write(s.unit);
      }
    }
    return buffer.toString();
  }

  factory MemorialDay.fromApi(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>>? types,
  }) {
    final typeId = _asInt(json['type_id']);
    var typeMap = json['type'] is Map
        ? Map<String, dynamic>.from(json['type'] as Map)
        : null;
    if (typeMap == null && types != null && typeId != null) {
      for (final t in types) {
        if (_asInt(t['id']) == typeId) {
          typeMap = t;
          break;
        }
      }
    }
    final typeTitle = typeMap?['title']?.toString() ?? '';
    final parsed = DateTime.tryParse(json['date']?.toString() ?? '') ??
        DateTime.now();

    return MemorialDay(
      id: '${json['id']}',
      title: json['name']?.toString() ?? '',
      type: typeFromTitle(typeTitle),
      date: parsed,
      typeId: typeId,
      calendarType:
          json['date_type'] == 2 ? CalendarType.lunar : CalendarType.solar,
      repeatFrequency: _repeatFromApi(json['repeat_frequency']),
      isPinned: json['is_top'] == 1,
      hasReminder: json['is_remind'] == 1,
      customTypeName: typeTitle.isNotEmpty ? typeTitle : null,
      typeBgColorHex: typeMap?['bg_color']?.toString(),
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v');
  }

  static MemorialType typeFromTitle(String title) {
    if (title.contains('生日')) return MemorialType.birthday;
    if (title.contains('节日')) return MemorialType.festival;
    if (title.contains('工作')) return MemorialType.work;
    if (title.contains('生活')) return MemorialType.life;
    if (title.contains('事件')) return MemorialType.event;
    return MemorialType.custom;
  }

  /// 接口 repeat_frequency：0-不重复，1-每天，2-每周，3-每月，4-每年
  static RepeatFrequency _repeatFromApi(dynamic v) {
    switch (_asInt(v)) {
      case 0:
        return RepeatFrequency.none;
      case 1:
        return RepeatFrequency.daily;
      case 2:
        return RepeatFrequency.weekly;
      case 3:
        return RepeatFrequency.monthly;
      case 4:
        return RepeatFrequency.yearly;
      default:
        return RepeatFrequency.yearly;
    }
  }

  static int repeatToApi(RepeatFrequency f) {
    switch (f) {
      case RepeatFrequency.none:
        return 0;
      case RepeatFrequency.daily:
        return 1;
      case RepeatFrequency.weekly:
        return 2;
      case RepeatFrequency.monthly:
        return 3;
      case RepeatFrequency.yearly:
        return 4;
    }
  }
}
