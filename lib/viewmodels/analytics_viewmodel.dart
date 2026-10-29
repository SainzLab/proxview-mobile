import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';

class AnalyticsViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  SlaAnalyticsResponseModel? _analytics;
  String _selectedPeriod = '24h'; // '24h', '7d', '30d'
  String _selectedSeverity = 'ALL'; // 'ALL', 'DOWN', 'CRITICAL', 'WARNING'
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;

  CancelToken? _cancelToken;

  AnalyticsViewModel(this._apiService);

  SlaAnalyticsResponseModel? get analytics => _analytics;
  String get selectedPeriod => _selectedPeriod;
  String get selectedSeverity => _selectedSeverity;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAnalytics({
    String? period,
    String? severity,
    bool showLoading = true,
  }) async {
    final filterChanged =
        (period != null && period != _selectedPeriod) ||
        (severity != null && severity != _selectedSeverity);
    if (period != null) _selectedPeriod = period;
    if (severity != null) _selectedSeverity = severity;

    if (!showLoading && !filterChanged && _isFetching) return;

    if (showLoading || filterChanged) {
      _cancelToken?.cancel('Filter analytics berubah');
    }

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    _isFetching = true;
    final token = CancelToken();
    _cancelToken = token;

    try {
      _analytics = await _apiService.getAnalytics(
        period: _selectedPeriod,
        severity: _selectedSeverity,
        cancelToken: token,
      );
      _errorMessage = null;
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (showLoading || _analytics == null) {
        _errorMessage = e.toString();
      }
    } catch (e) {
      if (showLoading || _analytics == null) {
        _errorMessage = e.toString();
      }
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel('ViewModel disposed');
    super.dispose();
  }
}
