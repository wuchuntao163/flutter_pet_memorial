import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/memorial_day.dart';

/// 纪念日类型配色（首页天数区与添加页类型选中共用）
class MemorialTypeTheme {
  MemorialTypeTheme._();

  /// 首页卡片左侧「天数」背景色
  static Color daysBackground(MemorialType type) {
    switch (type) {
      case MemorialType.birthday:
        return const Color(0xFFF9C2C2);
      case MemorialType.event:
        return const Color(0xFFD9E9F9);
      case MemorialType.festival:
        return const Color(0xFFFFF9E1);
      case MemorialType.work:
        return const Color(0xFFD9E9F9);
      case MemorialType.life:
        return const Color(0xFFE8F5E9);
      case MemorialType.custom:
        return const Color(0xFFFFE8D6);
    }
  }

  /// 首页卡片左侧「天数」文字色
  static Color daysText(MemorialType type) {
    switch (type) {
      case MemorialType.birthday:
        return const Color(0xFFB05B5B);
      case MemorialType.event:
        return const Color(0xFF5B7B9B);
      case MemorialType.festival:
        return const Color(0xFF8B864E);
      case MemorialType.work:
        return const Color(0xFF5B7B9B);
      case MemorialType.life:
        return const Color(0xFF4A7C59);
      case MemorialType.custom:
        return const Color(0xFFC2410C);
    }
  }

  static Color tagBackground(MemorialType type) => daysBackground(type);

  /// 详情页顶部倒计时卡片渐变
  static List<Color> detailGradient(MemorialType type) {
    final base = daysBackground(type);
    return [
      Color.lerp(base, Colors.white, 0.15)!,
      Color.lerp(base, AppColors.bgWhite, 0.35)!,
    ];
  }

  static Color tagText(MemorialType type) => daysText(type);
}
