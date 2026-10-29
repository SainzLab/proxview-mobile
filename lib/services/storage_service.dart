import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _keyApiToken = 'proxview_api_token';
  static const String _keyBaseUrl = 'proxview_base_url';
  static const String _keyCachedUser = 'proxview_cached_user';
  static const String _keyDarkMode = 'proxview_dark_mode';
  static const String defaultBaseUrl = 'http://192.168.8.10:7060/api/mobile/v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Fallback in-memory (tidak disimpan ke disk plaintext) bila secure enclave gagal diakses
  String? _inMemoryTokenFallback;

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
  /// - Memprioritaskan https:// untuk domain publik tanpa port khusus
  /// - Menerima IP address, domain/subdomain, maupun localhost (dengan atau tanpa port)
  /// - Otomatis melengkapi suffix /api/mobile/v1 bila belum ada
  static String normalizeBaseUrl(String rawUrl) {
    String url = rawUrl.trim();
    if (url.isEmpty) return defaultBaseUrl;

    final lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      final isLoopbackOrPrivateCustomPort = lower.startsWith('localhost') ||
          lower.startsWith('127.0.0.1') ||
          lower.startsWith('10.0.2.2') ||
          lower.contains(':80') ||
          (RegExp(r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)').hasMatch(lower) &&
              lower.contains(':') &&
              !lower.contains(':443'));

      if (lower.contains(':443') || !isLoopbackOrPrivateCustomPort) {
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

  /// Memvalidasi apakah format input URL server memiliki host & skema yang sah
  static bool isValidServerUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return false;

    final normalized = normalizeBaseUrl(trimmed);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;

    final host = uri.host.trim();
    if (host.isEmpty ||
        host.startsWith('.') ||
        host.endsWith('.') ||
        host.contains('..')) {
      return false;
    }

    final validHostPattern = RegExp(r'^[a-zA-Z0-9.-]+$');
    final isIpv6 = host.contains(':') && Uri.tryParse('http://[$host]') != null;
    if (!validHostPattern.hasMatch(host) && !isIpv6) return false;

    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
    return true;
  }

  /// Mengekstrak nama host dari URL server untuk validasi sertifikat SSL terbatas
  static String? extractHost(String rawUrl) {
    final uri = Uri.tryParse(normalizeBaseUrl(rawUrl));
    final host = uri?.host.trim().toLowerCase();
    return (host != null && host.isNotEmpty) ? host : null;
  }

  Future<String?> getApiToken() async {
    try {
      final token = await _secureStorage.read(key: _keyApiToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      if (_inMemoryTokenFallback != null && _inMemoryTokenFallback!.isNotEmpty) {
        return _inMemoryTokenFallback;
      }
    }

    // Migrasi satu arah bila ada token lama yang sempat tersimpan di SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_keyApiToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await prefs.remove(_keyApiToken);
        await saveApiToken(legacyToken);
        return legacyToken;
      }
    } catch (_) {}

    return _inMemoryTokenFallback;
  }

  Future<void> saveApiToken(String token) async {
    _inMemoryTokenFallback = token;
    try {
      await _secureStorage.write(key: _keyApiToken, value: token);
    } catch (_) {
      // Gunakan _inMemoryTokenFallback bila KeyStore tidak tersedia di environment test
    }
    // Pastikan tidak ada token plaintext yang tertinggal di SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyApiToken)) {
        await prefs.remove(_keyApiToken);
      }
    } catch (_) {}
  }

  Future<void> saveCachedUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedUser, jsonEncode(user.toSafeCacheJson()));
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
    _inMemoryTokenFallback = null;
    try {
      await _secureStorage.delete(key: _keyApiToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiToken);
    await prefs.remove(_keyCachedUser);
  }
}
