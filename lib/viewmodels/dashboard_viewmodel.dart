import 'package:flutter/foundation.dart';
import '../models/dashboard_model.dart';
import '../services/api_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  SystemStatusModel? _systemStatus;
  DashboardSummaryModel? _summary;
  String _selectedTimeframe = '1h'; // '1h', '24h', '7d'
  bool _isLoading = false;
  String? _errorMessage;

  DashboardViewModel(this._apiService);

  SystemStatusModel? get systemStatus => _systemStatus;
  DashboardSummaryModel? get summary => _summary;
  String get selectedTimeframe => _selectedTimeframe;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboard({bool showLoading = true, String? timeframe}) async {
    if (timeframe != null) {
      _selectedTimeframe = timeframe;
    }
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _apiService.getSystemStatus(),
        _apiService.getDashboardSummary(timeframe: _selectedTimeframe),
      ]);
      _systemStatus = results[0] as SystemStatusModel;
      _summary = results[1] as DashboardSummaryModel;
      _errorMessage = null;
    } catch (e) {
      if (showLoading || _summary == null) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
