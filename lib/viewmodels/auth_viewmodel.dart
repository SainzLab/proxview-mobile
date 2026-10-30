import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;
  final StorageService _storageService;

  AuthStatus _status = AuthStatus.checking;
  UserModel? _currentUser;
  String _baseUrl = StorageService.defaultBaseUrl;
  bool _isLoading = false;
  String? _errorMessage;

  AuthViewModel(this._apiService, this._storageService) {
    _apiService.onUnauthorizedOrForbidden = (statusCode, message) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = message;
      NotificationService().stopBackgroundService();
      // Sesi dicabut server: hentikan juga push FCM/CallKit ke perangkat ini
      unawaited(PushNotificationService().revokeToken());
      notifyListeners();
    };
  }

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  bool get isKepalaBidang => _currentUser?.isKepalaBidang ?? false;
  String get baseUrl => _baseUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initializeSession() async {
    _status = AuthStatus.checking;
    _errorMessage = null;
    notifyListeners();

    _baseUrl = await _storageService.getBaseUrl();
    final token = await _storageService.getApiToken();

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final user = await _apiService.getMe();
      if (!user.isActive) {
        await _storageService.clearSession();
        await NotificationService().stopBackgroundService();
        _status = AuthStatus.unauthenticated;
        _errorMessage = '[ERR-403] Akun Anda sedang dinonaktifkan oleh Administrator.';
      } else {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        await _syncBackgroundService(token);
      }
    } catch (e) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      if (e is ApiException && (e.statusCode == 401 || e.code == 'ERR-401')) {
        _errorMessage = null;
      } else {
        _errorMessage = e.toString();
      }
    }
    notifyListeners();
  }

  /// [fcmToken] opsional; bila tidak diberikan, token diambil otomatis dari
  /// [PushNotificationService] (dengan timeout, gagal tidak menghalangi login).
  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    required String token,
    String? fcmToken,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (serverUrl.trim().isNotEmpty) {
        await _storageService.setBaseUrl(serverUrl);
        _baseUrl = await _storageService.getBaseUrl();
      }

      final resolvedFcmToken =
          fcmToken ?? await PushNotificationService().fetchToken();

      final user = await _apiService.login(
        username: username,
        password: password,
        token: token,
        fcmToken: resolvedFcmToken,
      );

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _isLoading = false;

      final savedToken = await _storageService.getApiToken() ?? token;
      await _syncBackgroundService(savedToken);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    await _storageService.setBaseUrl(newUrl);
    _baseUrl = await _storageService.getBaseUrl();

    final token = await _storageService.getApiToken();
    if (token != null && token.isNotEmpty) {
      await _syncBackgroundService(token);
    }
    notifyListeners();
  }

  Future<void> _syncBackgroundService(String token) async {
    final enableForTeknisi = _status == AuthStatus.authenticated && !isKepalaBidang;

    await NotificationService().configureBackgroundService(
      baseUrl: _baseUrl,
      apiToken: token,
      enabled: enableForTeknisi,
    );

    if (enableForTeknisi) {
      unawaited(NotificationService().requestRuntimeAndBackgroundPermissions());
    }
  }

  Future<void> refreshProfile() async {
    try {
      _currentUser = await _apiService.getMe();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> logout({String? reason}) async {
    await _storageService.clearSession();
    await NotificationService().stopBackgroundService();
    // Cabut FCM token agar perangkat tidak lagi menerima panggilan darurat setelah logout
    await PushNotificationService().revokeToken();

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = reason;
    notifyListeners();
  }
}