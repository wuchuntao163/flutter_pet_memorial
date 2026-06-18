import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 应用字体：iOS 使用系统字体，其他平台使用内嵌 NotoSansSC。
abstract final class AppFonts {
  static String? get family {
    if (kIsWeb) return 'NotoSansSC';
    if (Platform.isIOS) return null;
    return 'NotoSansSC';
  }

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
