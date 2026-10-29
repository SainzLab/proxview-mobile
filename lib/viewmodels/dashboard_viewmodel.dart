import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/dashboard_model.dart';
import '../services/api_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  SystemStatusModel? _systemStatus;
  DashboardSummaryModel? _summary;
  String _selectedTimeframe = '1h'; // '1h', '24h', '7d'
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;

  CancelToken? _cancelToken;

  DashboardViewModel(this._apiService);

  SystemStatusModel? get systemStatus => _systemStatus;
  DashboardSummaryModel? get summary => _summary;
  String get selectedTimeframe => _selectedTimeframe;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboard({bool showLoading = true, String? timeframe}) async {
    final timeframeChanged =
        timeframe != null && timeframe != _selectedTimeframe;
    if (timeframe != null) {
      _selectedTimeframe = timeframe;
    }

    if (!showLoading && !timeframeChanged && _isFetching) return;

    if (showLoading || timeframeChanged) {
      _cancelToken?.cancel('Memuat timeframe baru');
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
      final results = await Future.wait([
        _apiService.getSystemStatus(cancelToken: token),
        _apiService.getDashboardSummary(
          timeframe: _selectedTimeframe,
          cancelToken: token,
        ),
      ]);
      if (token.isCancelled) return;
      _systemStatus = results[0] as SystemStatusModel;
      _summary = results[1] as DashboardSummaryModel;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (showLoading || _summary == null) {
        _errorMessage = e.toString();
      }
    } catch (e) {
      if (showLoading || _summary == null) {
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
