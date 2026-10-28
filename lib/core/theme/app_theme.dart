import 'package:flutter/material.dart';

class AppTheme {
  // Core Surface & Background Palette (Untuk referensi custom painting/widget)
  static const Color background = Color(0xFF05070A);
  static const Color cardBackground = Color(0xFF0D1117);
  static const Color surfaceBackground = Color(0xFF161B22);
  static const Color elevatedBackground = Color(0xFF1E2530);
  static const Color borderSubtle = Color(0x1AFFFFFF); // Colors.white10
  static const Color borderHighlight = Color(0x33FFFFFF); // Colors.white20

  // Light Theme Specific Colors (Bisa dipanggil manual jika butuh custom shadow/border)
  static const Color lightBg = Color(0xFFF8F9FA); // slate-50
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0); // slate-200
  static const Color lightText = Color(0xFF0F172A); // slate-900

  // Unified Status & Severity Colors (Dipertahankan agar logic berjalan mulus)
  static const Color statusTeal = Color(0xFF10B981); // Emerald (menyesuaikan web)
  static const Color statusWarning = Color(0xFFFBBF24); // Amber
  static const Color statusCritical = Color(0xFFFB923C); // Orange
  static const Color statusDown = Color(0xFFF43F5E); // Rose Red
  static const Color statusRecovered = Color(0xFF38BDF8); // Sky / Cyan Info

  // ==========================================
  // TEMA TERANG (LIGHT THEME)
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: statusTeal,
      cardColor: lightCard,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: statusTeal,
        secondary: statusTeal,
        surface: lightCard,
        error: statusDown,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          fontSize: 19,
          color: lightText,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: lightCard,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: lightText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // TEMA GELAP (DARK THEME)
  // ==========================================
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: statusTeal,
      cardColor: cardBackground,
      fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
    return const Color(0xFF94A3B8); // slate-400 sebagai default
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