import 'package:flutter/material.dart';

// === IMPORTANT
// Replace the hex values in AppColors with your project's exact hex codes
// from 2025-CP_TAPSAKAY-main (1).zip
class AppColors {
  static const primary = Color(0xFF0B74FF);
  static const accent  = Color(0xFFFFC107);
  static const bg      = Color(0xFFF6F8FB);
  static const text    = Color(0xFF263238);
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.fromSwatch().copyWith(secondary: AppColors.accent),
  scaffoldBackgroundColor: AppColors.bg,
  appBarTheme: const AppBarTheme(backgroundColor: AppColors.primary, elevation: 0),
  textTheme: const TextTheme(bodyMedium: TextStyle(color: AppColors.text)),
);
