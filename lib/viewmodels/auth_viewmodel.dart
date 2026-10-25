import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  final ViewMoxApiService _apiService;
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
      notifyListeners();
    };
  }

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
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
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Akun Anda sedang dinonaktifkan oleh Administrator.';
      } else {
        _currentUser = user;
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (serverUrl.trim().isNotEmpty) {
        await _storageService.setBaseUrl(serverUrl);
        _baseUrl = await _storageService.getBaseUrl();
      }
      final user = await _apiService.login(
        username: username,
        password: password,
        token: token,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      _isLoading = false;
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
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      _currentUser = await _apiService.getMe();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout({String? reason}) async {
    await _storageService.clearSession();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = reason;
    notifyListeners();
  }
}
