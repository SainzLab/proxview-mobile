import 'package:flutter/foundation.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';

class AnalyticsViewModel extends ChangeNotifier {
  final ViewMoxApiService _apiService;

  SlaAnalyticsResponseModel? _analytics;
  String _selectedPeriod = '24h'; // '24h', '7d', '30d'
  String _selectedSeverity = 'ALL'; // 'ALL', 'DOWN', 'CRITICAL', 'WARNING'
  bool _isLoading = false;
  String? _errorMessage;

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
    if (period != null) _selectedPeriod = period;
    if (severity != null) _selectedSeverity = severity;

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _analytics = await _apiService.getAnalytics(
        period: _selectedPeriod,
        severity: _selectedSeverity,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
