import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

class ThemeViewModel extends ChangeNotifier {
  final StorageService _storageService;
  bool _isDarkMode = false;

  ThemeViewModel(this._storageService);

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadTheme() async {
    _isDarkMode = await _storageService.getIsDarkMode(defaultValue: false);
    AppTheme.isDark = _isDarkMode;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    AppTheme.isDark = value;
    notifyListeners();
    await _storageService.setIsDarkMode(value);
  }

  Future<void> toggleTheme() => setDarkMode(!_isDarkMode);
}

class AppTheme {
  static bool isDark = false;

  // Core Surface & Background Palette (Dark Mode)
  static const Color background = Color(0xFF0B0F19); // Deep Slate Midnight
  static const Color cardBackground = Color(0xFF111827); // Slate 900
  static const Color surfaceBackground = Color(0xFF1E293B); // Slate 800
  static const Color elevatedBackground = Color(0xFF26334D);
  static const Color borderSubtle = Color(0xFF26334D); // Subtle Dark Border
  static const Color borderHighlight = Color(0xFF334155); // Slate 700
  static const Color darkTextMain = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color darkTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextHint = Color(0xFF64748B); // Slate 500

  // Light Theme Specific Colors
  static const Color lightBg = Color(0xFFF8F9FA); // slate-50
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Color(0xFFF1F5F9); // slate-100
  static const Color lightBorder = Color(0xFFE2E8F0); // slate-200
  static const Color lightText = Color(0xFF0F172A); // slate-900
  static const Color lightTextSecondary = Color(0xFF475569); // slate-600
  static const Color lightTextMuted = Color(0xFF64748B); // slate-500
  static const Color lightTextHint = Color(0xFF94A3B8); // slate-400

  // Adaptive Getters (Otomatis menyesuaikan Mode Terang / Mode Gelap)
  static Color get bgMain => isDark ? background : lightBg;
  static Color get bgCard => isDark ? cardBackground : lightCard;
  static Color get bgSurface => isDark ? surfaceBackground : lightSurface;
  static Color get borderColor => isDark ? borderSubtle : lightBorder;
  static Color get textMain => isDark ? darkTextMain : lightText;
  static Color get textSecondary => isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted => isDark ? darkTextMuted : lightTextMuted;
  static Color get textHint => isDark ? darkTextHint : lightTextHint;
  static Color get gridLineColor => isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.05);

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