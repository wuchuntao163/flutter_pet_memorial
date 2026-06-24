import 'package:flutter/material.dart';

/// 应用字体：各平台使用系统默认字体。
abstract final class AppFonts {
  static String? get family => null;

  static TextStyle get pickerItem => TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get dialogTitle => TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get dialogAction => TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
}
