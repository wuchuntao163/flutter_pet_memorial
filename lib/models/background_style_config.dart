import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../l10n/tr.dart';
import '../data/background_store.dart';
import '../models/memorial_day.dart';
import '../widgets/common/memorial_type_info.dart';

/// 倒数日背景（接口 getBackgrounds + 首页类型色）
class BackgroundStyleConfig {
  BackgroundStyleConfig._();

  /// 首页纪念日卡片左侧天数区同色背景
  static const typeColorStyleId = 'type_color';

  static bool isTypeColorStyle(String styleId) =>
      styleId == typeColorStyleId;

  static List<Map<String, dynamic>> displayItems(MemorialDay day) {
    return [
      typeColorItem(day),
      ...BackgroundStore.instance.items,
    ];
  }

  static Map<String, dynamic> typeColorItem(MemorialDay day) => {
        'id': typeColorStyleId,
        'name': tr('style.default'),
        'is_local': 1,
      };

  static Map<String, dynamic>? itemFor(String styleId, MemorialDay day) {
    if (isTypeColorStyle(styleId)) return typeColorItem(day);
    return BackgroundStore.instance.findById(styleId);
  }

  static String effectiveStyleId(String styleId, {MemorialDay? day}) {
    if (isTypeColorStyle(styleId)) return styleId;
    if (styleId.isNotEmpty &&
        BackgroundStore.instance.findById(styleId) != null) {
      return styleId;
    }
    if (day != null) return typeColorStyleId;
    final items = BackgroundStore.instance.items;
    if (items.isNotEmpty) return '${items.first['id']}';
    return '';
  }

  static String? imageUrlFor(String styleId) {
    if (isTypeColorStyle(styleId)) return null;
    final id = effectiveStyleId(styleId);
    if (id.isEmpty || isTypeColorStyle(id)) return null;
    final url =
        BackgroundStore.instance.findById(id)?['image']?.toString();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  static String labelFor(String styleId, {MemorialDay? day}) {
    if (isTypeColorStyle(styleId)) return tr('style.default');
    final name =
        BackgroundStore.instance.findById(styleId)?['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return tr('style.background');
  }

  static BoxDecoration cardDecoration(
    String styleId, {
    required MemorialDay day,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
  }) {
    if (isTypeColorStyle(styleId)) {
      return BoxDecoration(
        borderRadius: borderRadius,
        color: MemorialTypeInfo.daysBackground(day),
      );
    }
    final url = imageUrlFor(styleId);
    return BoxDecoration(
      borderRadius: borderRadius,
      color: url == null ? AppColors.bgInput : null,
      image: url != null
          ? DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            )
          : null,
    );
  }

  static Widget image(
    String styleId, {
    required MemorialDay day,
    BoxFit fit = BoxFit.cover,
  }) {
    if (isTypeColorStyle(styleId)) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: MemorialTypeInfo.daysBackground(day),
      );
    }
    final url = imageUrlFor(styleId);
    if (url != null) {
      return Image.network(
        url,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _placeholder(fit: fit),
      );
    }
    return _placeholder(fit: fit);
  }

  static Widget _placeholder({BoxFit fit = BoxFit.cover}) {
    return Container(
      color: AppColors.bgInput,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textTertiary.withValues(alpha: 0.5),
      ),
    );
  }
}

class BackgroundStyleSelection {
  final String styleId;
  final String? categoryId;

  const BackgroundStyleSelection({
    required this.styleId,
    this.categoryId,
  });
}
