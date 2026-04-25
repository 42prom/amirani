import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/tokens/app_tokens.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.colorBgPrimary,
      primaryColor: AppTokens.colorBrand,
      colorScheme: const ColorScheme.dark(
        primary: AppTokens.colorBrand,
        surface: AppTokens.colorBgSurface,
        onPrimary: Colors.white,
      ),
      textTheme:
          GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(
            color: AppTokens.colorTextPrimary,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        bodyLarge: const TextStyle(
            color: AppTokens.colorTextPrimary,
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        bodyMedium: const TextStyle(
            color: AppTokens.colorTextSecondary,
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        bodySmall: const TextStyle(
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        labelLarge: const TextStyle(
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        labelMedium: const TextStyle(
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTokens.colorTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.colorBrand,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.colorBgSurface,
        contentTextStyle: GoogleFonts.inter(
          color: AppTokens.colorTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppTokens.colorBrand.withValues(alpha: 0.5)),
        thickness: WidgetStateProperty.all(6.0),
        radius: const Radius.circular(12),
        interactive: true,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppTokens.colorBgSurface,
        headerBackgroundColor: AppTokens.colorBgPrimary,
        headerForegroundColor: AppTokens.colorBrand,
        dividerColor: Colors.white.withValues(alpha: 0.1),
        dayStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        yearStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppTokens.colorBgSurface,
        hourMinuteColor: AppTokens.colorBgPrimary,
        hourMinuteTextColor: AppTokens.colorBrand,
        dayPeriodColor: AppTokens.colorBgPrimary,
        dayPeriodTextColor: AppTokens.colorBrand,
        dialBackgroundColor: AppTokens.colorBgPrimary,
        dialHandColor: AppTokens.colorBrand,
        dialTextColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
