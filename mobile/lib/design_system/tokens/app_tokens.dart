import 'package:flutter/material.dart';

/// Centralized design tokens for the Amirani platform.
/// All UI code must reference these instead of hardcoded values.
class AppTokens {
  AppTokens._();

  // ─── Colors ──────────────────────────────────────────────────────────────
  static const Color colorBrand = Color(0xFFF1C40F);        // Amirani Yellow
  static const Color colorBrandDim = Color(0x1FF1C40F);     // 12% yellow
  static const Color colorBrandBorder = Color(0x59F1C40F);  // 35% yellow

  static const Color colorBgPrimary = Color(0xFF121721);    // Deep dark
  static const Color colorBgSurface = Color(0xFF1A2035);    // Card surface
  static const Color colorBgSurfaceAlt = Color(0xFF1E2640); // Elevated surface

  static const Color colorTextPrimary = Color(0xFFFFFFFF);
  static const Color colorTextSecondary = Color(0xFFA0AABF);
  static const Color colorTextMuted = Color(0xFF6B7280);

  static const Color colorSuccess = Color(0xFF10B981);      // Green
  static const Color colorWarning = Color(0xFFF59E0B);      // Amber
  static const Color colorError = Color(0xFFEF4444);        // Red
  static const Color colorInfo = Color(0xFF3B82F6);         // Blue

  static const Color colorBorderSubtle = Color(0x14FFFFFF); // 8% white
  static const Color colorBorderMedium = Color(0x26FFFFFF); // 15% white

  // Score ring colors (match directive 04)
  static const Color colorScoreWorkout = Color(0xFFF1C40F); // Yellow
  static const Color colorScoreDiet = Color(0xFF10B981);    // Green
  static const Color colorScoreHydration = Color(0xFF3B82F6); // Blue
  static const Color colorScoreSleep = Color(0xFF8B5CF6);   // Purple

  // ─── Spacing ─────────────────────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ─── Radius ───────────────────────────────────────────────────────────────
  static const double radius8 = 8.0;
  static const double radius10 = 10.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius32 = 32.0;
  static const double radiusFull = 999.0;

  // ─── Typography ──────────────────────────────────────────────────────────
  static const TextStyle textDisplayLg = TextStyle(
    color: colorTextPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle textDisplayMd = TextStyle(
    color: colorTextPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle textHeadingLg = TextStyle(
    color: colorTextPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle textHeadingMd = TextStyle(
    color: colorTextPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle textBodyLg = TextStyle(
    color: colorTextPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle textBodyMd = TextStyle(
    color: colorTextSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle textCaption = TextStyle(
    color: colorTextMuted,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static const TextStyle textLabelSm = TextStyle(
    color: colorTextSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowModal => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ];

  // ─── Durations ───────────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration animChart = Duration(milliseconds: 800);
}
