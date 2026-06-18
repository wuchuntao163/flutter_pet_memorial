import 'package:flutter/material.dart';

import '../../data/memorial_store.dart';
import '../../models/memorial_day.dart';
import '../../services/pet_image_service.dart';
import '../../theme/memorial_type_theme.dart';

/// 纪念日类型展示（与首页列表卡片共用）
class MemorialTypeInfo {
  MemorialTypeInfo._();

  static String label(MemorialDay day) {
    final fromTypeId =
        MemorialStore.instance.typeTitleFor(day.typeId).trim();
    if (fromTypeId.isNotEmpty) return fromTypeId;
    return day.typeLabel;
  }

  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  static String? bgColorHex(MemorialDay day) =>
      day.typeBgColorHex ??
      MemorialStore.instance.typeById(day.typeId)?['bg_color']?.toString();

  static Color daysBackground(MemorialDay day) {
    final api = parseColor(bgColorHex(day));
    if (api != null) return Color.lerp(api, Colors.white, 0.55)!;
    return MemorialTypeTheme.daysBackground(day.type);
  }

  static Color daysText(MemorialDay day) {
    final api = parseColor(bgColorHex(day));
    if (api != null) return Color.lerp(api, const Color(0xFF1A1A1A), 0.55)!;
    return MemorialTypeTheme.daysText(day.type);
  }

  static Color tagBackground(MemorialDay day) => daysBackground(day);

  static Color tagText(MemorialDay day) => daysText(day);

  /// getTypes 的 icon 字段
  static Widget typeIcon(
    Map<String, dynamic> type, {
    double size = 18,
    Color? color,
  }) {
    return _icon(type['icon']?.toString(), size: size, color: color);
  }

  static Widget icon(MemorialDay day, {double size = 16, Color? color}) {
    final type = MemorialStore.instance.typeById(day.typeId);
    if (type != null) {
      return typeIcon(type, size: size, color: color ?? daysText(day));
    }
    return _icon(null, size: size, color: color ?? daysText(day));
  }

  static Widget _icon(String? url, {required double size, Color? color}) {
    final value = url?.trim() ?? '';
    if (value.isNotEmpty) {
      return Image.network(
        PetImageService.resolveUrl(value),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.label_outline, size: size, color: color),
      );
    }
    return Icon(Icons.label_outline, size: size, color: color);
  }
}
