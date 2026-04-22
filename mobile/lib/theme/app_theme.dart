import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryBrand = Color(0xFFF1C40F); // Amirani Yellow
  static const Color maleBlue = Color(0xFF2D9CDB); // Vibrant Cyan-Blue
  static const Color femalePink = Color(0xFFFF52AF); // Luminous Pink
  static const Color backgroundDark = Color(0xFF121721); // Aligned with Directive 01
  static const Color surfaceDark = Color(0xFF1A2035); // Aligned with Directive 01
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AABF); // Aligned with Directive 01
  
  // Standardized Modal Tokens
  static Color get modalBackground => backgroundDark.withValues(alpha: 0.7);
  static const double modalBlur = 20.0;
  static const double modalRadius = 32.0;
  static Color get modalHandleColor => Colors.white.withValues(alpha: 0.2);
  static const EdgeInsets modalPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryBrand,
      colorScheme: const ColorScheme.dark(
        primary: primaryBrand,
        surface: surfaceDark,
        onPrimary: Colors.white,
      ),
      textTheme:
          GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        bodyLarge: const TextStyle(
            color: textPrimary,
            fontFamilyFallback: ['NotoSans', 'sans-serif']),
        bodyMedium: const TextStyle(
            color: textSecondary,
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
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDark,
        contentTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(primaryBrand.withValues(alpha: 0.5)),
        thickness: WidgetStateProperty.all(6.0),
        radius: const Radius.circular(12),
        interactive: true,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaceDark,
        headerBackgroundColor: backgroundDark,
        headerForegroundColor: primaryBrand,
        dividerColor: Colors.white.withValues(alpha: 0.1),
        dayStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        yearStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surfaceDark,
        hourMinuteColor: backgroundDark,
        hourMinuteTextColor: primaryBrand,
        dayPeriodColor: backgroundDark,
        dayPeriodTextColor: primaryBrand,
        dialBackgroundColor: backgroundDark,
        dialHandColor: primaryBrand,
        dialTextColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
