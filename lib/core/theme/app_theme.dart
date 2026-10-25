import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Colors.black;
  static const Color cardBackground = Color(0xFF0A0A0A);
  static const Color surfaceBackground = Color(0xFF0F0F0F);
  static const Color borderSubtle = Colors.white10;

  // Status & Severity Colors
  static const Color statusTeal = Colors.tealAccent;
  static const Color statusWarning = Colors.amber;
  static const Color statusCritical = Colors.orangeAccent;
  static const Color statusDown = Colors.redAccent;
  static const Color statusRecovered = Colors.lightBlueAccent;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: Colors.white,
      cardColor: cardBackground,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: statusTeal,
        surface: cardBackground,
        error: statusDown,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        toolbarHeight: 68,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Color severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'WARNING':
        return statusWarning;
      case 'CRITICAL':
        return statusCritical;
      case 'DOWN':
        return statusDown;
      case 'RECOVERED':
      case 'UP':
      case 'ACTIVE':
      case 'ONLINE':
      case 'RUNNING':
      case 'TERHUBUNG':
        return statusTeal;
      default:
        return Colors.white54;
    }
  }

  static IconData severityIcon(String severity) {
    switch (severity.toUpperCase()) {
      case 'WARNING':
        return Icons.warning_amber_rounded;
      case 'CRITICAL':
        return Icons.report_problem_outlined;
      case 'DOWN':
        return Icons.error_outline_rounded;
      case 'RECOVERED':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
