import 'package:flutter/material.dart';
import 'colors.dart';
import 'fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final family = AppFonts.family;
    return ThemeData(
      useMaterial3: false,
      fontFamily: family,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        toolbarHeight: 44,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: family,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.bottomNavActiveText,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: family,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.bottomNavInactiveText,
        ),
      ),
    );
  }
}
