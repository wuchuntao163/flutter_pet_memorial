import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background
  static const Color bgPrimary = Color(0xFFFEF8F1);
  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color bgInput = Color(0xFFF3EDE6);
  static const Color bgButtonSecondary = Color(0xFFEDE7E0);

  // Brand / Accent
  static const Color accent = Color(0xFFFFB2A6);
  static const Color petTypeAiButton = Color(0xFFFEBDCA);
  static const Color avatarGradientStart = Color(0xFFFFCAC3);
  static const Color avatarGradientEnd = Color(0xFFFFB3A6);
  static const Color avatarGenerateButtonText = Color(0xFF21211C);
  static const LinearGradient avatarGenerateGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [avatarGradientStart, avatarGradientEnd],
  );
  static const Color avatarActionGradientStart = Color(0xFFF6DBB1);
  static const Color avatarActionGradientEnd = Color(0xFFFFBA6F);
  static const LinearGradient avatarActionGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [avatarActionGradientStart, avatarActionGradientEnd],
  );
  static const Color accentDark = Color(0xFF894E45);
  static const Color accentDarker = Color(0xFF7A4239);
  static const Color gold = Color(0xFFFDD6A7);
  static const Color goldText = Color(0xFF785C35);
  static const Color blue = Color(0xFF98CBF2);
  static const Color blueText = Color(0xFF2E6385);
  static const Color orange = Color(0xFFFB923C);

  // Text
  static const Color textPrimary = Color(0xFF1D1B17);
  static const Color textSecondary = Color(0xFF524341);
  static const Color textTertiary = Color(0xFF857370);
  static const Color textPlaceholder = Color(0xFFD7C2BE);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textLightGray = Color(0xFF9CA3AF);
  static const Color textSuccess = Color(0xFF59631E);

  // Border
  static const Color borderLight = Color(0xFFF3EDE6);
  static const Color borderMedium = Color(0xFFEDE7E0);
  static const Color borderPlaceholder = Color(0xFFD7C2BE);

  // Gradient
  static const Color gradientPink = Color(0xFFFFF5F5);
  static const Color gradientGreen = Color(0xFFF0FFF4);
  static const Color gradientGoldStart = Color(0xFFFDD6A7);
  static const Color gradientGoldEnd = Color(0xFFFFDAD4);

  // Semantic
  static const Color delete = Color(0xFFBA1A1A);
  static const Color deleteBg = Color(0xFFFFDAD6);

  // Bottom Nav
  static const Color bottomNavActive = Color(0xFFFFB2A6);
  static const Color bottomNavActiveText = Color(0xFF7A4239);
  static const Color bottomNavInactiveText = Color(0xFF857370);

  // Switch
  static const Color switchOff = Color(0xFFE7E2DB);
  static const Color switchOn = Color(0xFFFFB2A6);

  // Modal
  /// 样式弹窗顶部标题栏背景
  static const Color modalHeaderBg = Color(0xFFFFF3E6);
  /// 弹窗确定按钮、选中高亮
  static const Color modalHeader = Color(0xFFFFBA6F);
  static const Color modalHeaderText = Color(0xFF8C5A45);
  static const Color uploadBorder = Color(0xFFFFB2A6);
  static const Color uploadBg = Color(0xFFFFF9F0);
  static const Color inputBorder = Color(0xFFFFEAD4);
  static const Color avatarDescriptionBorder = Color(0xFFFFB9AD);
}