import '../data/app_cache_store.dart';
import '../services/language_service.dart';

/// 根据当前语言解析接口 `language_id`
class LanguageIdUtil {
  LanguageIdUtil._();

  static int? resolve() {
    final fontName = LanguageService.instance.fontName;
    for (final raw in AppCacheStore.instance.languageList) {
      if (raw is! Map) continue;
      if (raw['font_name']?.toString() != fontName) continue;
      return int.tryParse('${raw['id']}');
    }
    return null;
  }

  /// 有语言 ID 时写入 [params]，并返回同一 map
  /// 暂时不向接口传 language_id
  static Map<String, dynamic> apply(Map<String, dynamic> params) {
    // final id = resolve();
    // if (id != null) params['language_id'] = id;
    return params;
  }

  /// 背景分类 / 背景列表等需要 language_id 的接口
  static Map<String, dynamic> withLanguageId(Map<String, dynamic> params) {
    final id = resolve();
    if (id != null) params['language_id'] = id;
    return params;
  }
}
