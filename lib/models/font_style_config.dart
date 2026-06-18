import '../data/font_style_store.dart';
import '../l10n/tr.dart';

/// 倒数日数字样式（接口 getFontStyles + 本地默认「普通数字」）
class FontStyleConfig {
  FontStyleConfig._();

  static const normalStyleId = 'normal';

  static bool isNormalStyle(String styleId) => styleId == normalStyleId;

  static List<Map<String, dynamic>> displayItems() {
    return [
      _normalItem(),
      ...FontStyleStore.instance.items,
    ];
  }

  static Map<String, dynamic> _normalItem() => {
        'id': normalStyleId,
        'name': tr('style.normal_number'),
        'is_local': 1,
      };

  static Map<String, dynamic>? itemFor(String styleId) {
    if (isNormalStyle(styleId)) return _normalItem();
    return FontStyleStore.instance.findById(styleId);
  }

  static String effectiveStyleId(String styleId) {
    if (isNormalStyle(styleId)) return styleId;
    if (styleId.isNotEmpty && FontStyleStore.instance.findById(styleId) != null) {
      return styleId;
    }
    final items = FontStyleStore.instance.items;
    if (items.isNotEmpty) return '${items.first['id']}';
    return normalStyleId;
  }

  static String labelFor(String styleId) {
    if (isNormalStyle(styleId)) return tr('style.normal_number');
    final name = FontStyleStore.instance.findById(styleId)?['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return tr('style.number_style');
  }

  static List<String> imageUrlsFor(String styleId) {
    if (isNormalStyle(styleId)) return [];
    final raw = FontStyleStore.instance.findById(styleId)?['images'];
    return FontStyleStore.parseImages(raw);
  }

  static String? previewImageUrl(String styleId) {
    final urls = imageUrlsFor(styleId);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// `images` 至少 10 张时，按索引 0–9 对应数字 0–9（单位天/周/月/年统一用文字）
  static List<String>? digitImageUrls(String styleId) {
    if (isNormalStyle(styleId)) return null;
    final urls = imageUrlsFor(styleId);
    if (urls.length < 10) return null;
    return urls.take(10).toList();
  }
}
