import 'package:flutter/foundation.dart';
import '../models/network_target_model.dart';
import '../services/api_service.dart';

class NetworkViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  List<NetworkTargetModel> _targets = [];
  String _protocolFilter = 'ALL'; // 'ALL', 'ICMP PING', 'TCP SOCKET'
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  final Map<int, List<TargetLatencyPointModel>> _historyCache = {};
  bool _isHistoryLoading = false;

  NetworkViewModel(this._apiService);

  List<NetworkTargetModel> get targets {
    var list = _targets;
    if (_protocolFilter != 'ALL') {
      list = list
          .where((t) => t.protocol.toUpperCase().contains(_protocolFilter))
          .toList();
    }
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((t) {
      final portStr = t.port != null ? ':${t.port}' : '';
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.ipAddress.toLowerCase().contains(q) ||
          portStr.contains(q) ||
          t.protocol.toLowerCase().contains(q) ||
          t.status.toLowerCase().contains(q);
    }).toList();
  }

  List<NetworkTargetModel> get allTargets => _targets;
  String get protocolFilter => _protocolFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get errorMessage => _errorMessage;

  void setProtocolFilter(String filter) {
    _protocolFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<TargetLatencyPointModel> historyFor(int targetId) =>
      _historyCache[targetId] ?? const [];

  Future<void> fetchTargets({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _targets = await _apiService.getTargets();
      _errorMessage = null;
    } catch (e) {
      if (showLoading || _targets.isEmpty) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTargetHistory(int targetId, {bool showLoading = true}) async {
    if (showLoading) {
      _isHistoryLoading = true;
      notifyListeners();
    }
    try {
      final points = await _apiService.getTargetHistory(targetId);
      _historyCache[targetId] = points;
    } catch (_) {
      // Pertahankan cache sebelumnya jika gagal
    } finally {
      if (showLoading) {
        _isHistoryLoading = false;
      }
      notifyListeners();
    }
  }
}
