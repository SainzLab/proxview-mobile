import 'package:flutter/material.dart';

class AppTheme {
  // Core Surface & Background Palette
  static const Color background = Color(0xFF05070A);
  static const Color cardBackground = Color(0xFF0D1117);
  static const Color surfaceBackground = Color(0xFF161B22);
  static const Color elevatedBackground = Color(0xFF1E2530);
  static const Color borderSubtle = Color(0x1AFFFFFF); // Colors.white10
  static const Color borderHighlight = Color(0x33FFFFFF); // Colors.white20

  // Unified Status & Severity Colors
  static const Color statusTeal = Color(0xFF2DD4BF); // Teal Accent selaras & kontras
  static const Color statusWarning = Color(0xFFFBBF24); // Amber
  static const Color statusCritical = Color(0xFFFB923C); // Orange
  static const Color statusDown = Color(0xFFF43F5E); // Rose Red
  static const Color statusRecovered = Color(0xFF38BDF8); // Sky / Cyan Info

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: statusTeal,
      cardColor: cardBackground,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: statusTeal,
        secondary: statusTeal,
        surface: cardBackground,
        error: statusDown,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontSize: 19,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceBackground,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static Color severityColor(String severity) {
    final upper = severity.trim().toUpperCase();
    if (upper.contains('WARNING') || upper.contains('WARN')) {
      return statusWarning;
    }
    if (upper.contains('CRITICAL') || upper.contains('CRIT')) {
      return statusCritical;
    }
    if (upper.contains('DOWN') ||
        upper.contains('ERROR') ||
        upper.contains('ERR') ||
        upper.contains('OFFLINE') ||
        upper.contains('STOPPED') ||
        upper.contains('FAIL')) {
      return statusDown;
    }
    if (upper.contains('PENANGANAN') ||
        upper.contains('PROGRES') ||
        upper.contains('PROGRESS') ||
        upper.contains('INFO')) {
      return statusRecovered;
    }
    if (upper.contains('RECOVERED') ||
        upper.contains('SELESAI') ||
        upper.contains('RESOLVED') ||
        upper.contains('UP') ||
        upper.contains('OK') ||
        upper.contains('ACTIVE') ||
        upper.contains('ONLINE') ||
        upper.contains('RUNNING') ||
        upper.contains('TERHUBUNG')) {
      return statusTeal;
    }
    return Colors.white54;
  }

  static IconData severityIcon(String severity) {
    final upper = severity.trim().toUpperCase();
    if (upper.contains('WARNING') || upper.contains('WARN')) {
      return Icons.warning_amber_rounded;
    }
    if (upper.contains('CRITICAL') || upper.contains('CRIT')) {
      return Icons.report_problem_rounded;
    }
    if (upper.contains('DOWN') ||
        upper.contains('ERROR') ||
        upper.contains('OFFLINE') ||
        upper.contains('FAIL')) {
      return Icons.error_outline_rounded;
    }
    if (upper.contains('PENANGANAN') ||
        upper.contains('PROGRES') ||
        upper.contains('INFO')) {
      return Icons.info_outline_rounded;
    }
    if (upper.contains('RECOVERED') ||
        upper.contains('SELESAI') ||
        upper.contains('UP') ||
        upper.contains('OK') ||
        upper.contains('ONLINE') ||
        upper.contains('RUNNING')) {
      return Icons.check_circle_outline_rounded;
    }
    return Icons.info_outline_rounded;
  }
}
