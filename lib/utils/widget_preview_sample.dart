import '../data/memorial_store.dart';
import '../models/memorial_day.dart';

/// 组件二级页预览静态样例（无真实纪念日时使用，不入库）。
class WidgetPreviewSample {
  WidgetPreviewSample._();

  static const sampleIdPrefix = '__preview_sample_';

  static const idPhoto = '${sampleIdPrefix}photo';
  static const idSimple = '${sampleIdPrefix}simple';
  static const idMedium = '${sampleIdPrefix}medium';
  static const idMulti1 = '${sampleIdPrefix}multi_1';
  static const idMulti2 = '${sampleIdPrefix}multi_2';
  static const idMulti3 = '${sampleIdPrefix}multi_3';

  static bool get shouldUse => MemorialStore.instance.items.isEmpty;

  static bool isSampleId(String? id) =>
      id != null && id.startsWith(sampleIdPrefix);

  /// 图文纪念日：生日、128、2026-11-22周日
  static MemorialDay forPhoto() => MemorialDay(
        id: idPhoto,
        title: '生日',
        type: MemorialType.birthday,
        date: DateTime(2026, 11, 22),
        customTypeName: '生日',
      );

  static const photoDays = 128;
  static const photoDateLabel = '2026-11-22  周日';

  /// 简约：365、最重要的一天
  static MemorialDay forSimple() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return MemorialDay(
      id: idSimple,
      title: '最重要的一天',
      type: MemorialType.event,
      date: today.add(const Duration(days: simpleDays)),
      customTypeName: '纪念日',
    );
  }

  static const simpleDays = 365;

  /// 中号：星期六、考试倒计时、168天、2025.6.8
  static MemorialDay forMedium() => MemorialDay(
        id: idMedium,
        title: '考试倒计时',
        type: MemorialType.work,
        date: DateTime(2025, 6, 8),
        customTypeName: '倒计时',
      );

  static const mediumDays = 168;
  static const mediumWeekday = '星期六';
  static const mediumDateLabel = '2025.6.8';

  /// 多纪念日 / 列表（相同三条）：类型色分别为生日 / 生活 / 事件（取接口专属色）
  static List<MemorialDay> forMulti() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      _typedSample(
        id: idMulti1,
        title: '毛毛出生啦',
        typeKeyword: '生日',
        fallbackType: MemorialType.birthday,
        date: today.subtract(const Duration(days: 1573)),
      ),
      _typedSample(
        id: idMulti2,
        title: '和好朋友认识已经',
        typeKeyword: '生活',
        fallbackType: MemorialType.life,
        date: today.subtract(const Duration(days: 3198)),
      ),
      _typedSample(
        id: idMulti3,
        title: '工作已经',
        typeKeyword: '事件',
        fallbackType: MemorialType.event,
        date: today.subtract(const Duration(days: 1128)),
      ),
    ];
  }

  static MemorialDay _typedSample({
    required String id,
    required String title,
    required String typeKeyword,
    required MemorialType fallbackType,
    required DateTime date,
  }) {
    final type = _typeByKeyword(typeKeyword);
    final typeTitle = type == null
        ? typeKeyword
        : MemorialStore.localizedTypeTitle(type);
    final resolvedType = typeTitle.isNotEmpty
        ? MemorialDay.typeFromTitle(typeTitle)
        : fallbackType;
    return MemorialDay(
      id: id,
      title: title,
      type: resolvedType,
      date: date,
      typeId: type == null ? null : int.tryParse('${type['id']}'),
      customTypeName: typeTitle.isNotEmpty ? typeTitle : typeKeyword,
      // 与首页列表一致：用 getTypes 返回的专属 bg_color
      typeBgColorHex: type?['bg_color']?.toString(),
    );
  }

  static Map<String, dynamic>? _typeByKeyword(String keyword) {
    for (final type in MemorialStore.instance.typeList) {
      final localized = MemorialStore.localizedTypeTitle(type);
      final raw = '${type['title'] ?? ''}';
      if (localized.contains(keyword) || raw.contains(keyword)) {
        return type;
      }
    }
    return null;
  }

  static const multiDays = <String, int>{
    idMulti1: 1573,
    idMulti2: 3198,
    idMulti3: 1128,
  };

  /// 样例固定展示天数（不随「今天」漂移的图文/中号；多纪念日/简约用日期差也可）
  static int? fixedDays(MemorialDay? item) {
    if (item == null || !isSampleId(item.id)) return null;
    switch (item.id) {
      case idPhoto:
        return photoDays;
      case idSimple:
        return simpleDays;
      case idMedium:
        return mediumDays;
      default:
        return multiDays[item.id];
    }
  }
}
