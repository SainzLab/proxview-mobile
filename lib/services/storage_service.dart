import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _keyApiToken = 'viewmox_api_token';
  static const String _keyBaseUrl = 'viewmox_base_url';
  static const String _keyCachedUser = 'viewmox_cached_user';
  static const String _keyDarkMode = 'viewmox_dark_mode';
  static const String defaultBaseUrl = 'http://192.168.8.10:7060/api/mobile/v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<bool> getIsDarkMode({bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? defaultValue;
  }

  Future<void> setIsDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, isDark);
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBaseUrl)?.trim();
    if (raw == null || raw.isEmpty) return defaultBaseUrl;
    return normalizeBaseUrl(raw);
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, normalizeBaseUrl(url));
  }

  /// Menormalisasi input URL secara fleksibel:
  /// - Menerima skema http:// maupun https://
  /// - Menerima IP address, domain/subdomain, maupun localhost (dengan atau tanpa port)
  /// - Otomatis melengkapi suffix /api/mobile/v1 bila belum ada
  static String normalizeBaseUrl(String rawUrl) {
    String url = rawUrl.trim();
    if (url.isEmpty) return defaultBaseUrl;

    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      if (lower.contains(':443')) {
        url = 'https://$url';
      } else {
        url = 'http://$url';
      }
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (!url.toLowerCase().endsWith('/api/mobile/v1')) {
      url = '$url/api/mobile/v1';
    }
    return url;
  }

  Future<String?> getApiToken() async {
    try {
      final token = await _secureStorage.read(key: _keyApiToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      // Fallback ke SharedPreferences bila platform keychain tidak tersedia
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiToken);
  }

  Future<void> saveApiToken(String token) async {
    try {
      await _secureStorage.write(key: _keyApiToken, value: token);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiToken, token);
  }

  Future<void> saveCachedUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedUser, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCachedUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _keyApiToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiToken);
    await prefs.remove(_keyCachedUser);
  }
}
