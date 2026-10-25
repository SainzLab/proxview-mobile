import 'package:flutter/foundation.dart';
import '../models/log_model.dart';
import '../services/api_service.dart';

class LogViewModel extends ChangeNotifier {
  final ViewMoxApiService _apiService;

  List<ProxmoxTaskLogModel> _taskLogs = [];
  List<ProxmoxClusterLogModel> _clusterLogs = [];
  List<SystemAuditLogModel> _systemLogs = [];

  bool _isLoading = false;
  bool _isTaskDetailLoading = false;
  bool _isLoadingMore = false; 
  String? _errorMessage;

  LogViewModel(this._apiService);

  List<ProxmoxTaskLogModel> get taskLogs => _taskLogs;
  List<ProxmoxClusterLogModel> get clusterLogs => _clusterLogs;
  List<SystemAuditLogModel> get systemLogs => _systemLogs;
  bool get isLoading => _isLoading;
  bool get isTaskDetailLoading => _isTaskDetailLoading;
  bool get isLoadingMore => _isLoadingMore; 
  String? get errorMessage => _errorMessage;

  Future<void> fetchLogs({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _apiService.getProxmoxTaskLogs(),
        _apiService.getProxmoxClusterLogs(),
        _apiService.getSystemAuditLogs(limit: 200),
      ]);
      _taskLogs = results[0] as List<ProxmoxTaskLogModel>;
      _clusterLogs = results[1] as List<ProxmoxClusterLogModel>;
      _systemLogs = results[2] as List<SystemAuditLogModel>;
      _errorMessage = null;
    } catch (e) {
      if (showLoading ||
          (_taskLogs.isEmpty && _clusterLogs.isEmpty && _systemLogs.isEmpty)) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> fetchTaskDetail({
    required String node,
    required String upid,
  }) async {
    _isTaskDetailLoading = true;
    notifyListeners();
    try {
      return await _apiService.getProxmoxTaskDetail(node: node, upid: upid);
    } catch (e) {
      return ['Gagal memuat detail task: $e'];
    } finally {
      _isTaskDetailLoading = false;
      notifyListeners();
    }
  }

  // --- Fungsi Infinite Scroll / Load More ---

  Future<void> loadMoreTasks() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda
      // Contoh: final newLogs = await _apiService.getProxmoxTaskLogs(offset: _taskLogs.length);
      // _taskLogs.addAll(newLogs);
      
      await Future.delayed(const Duration(seconds: 1)); // Simulasi loading
    } catch (e) {
      debugPrint('Gagal load more tasks: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreClusterLogs() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Gagal load more cluster logs: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSystemLogs() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda
      // Contoh: final newLogs = await _apiService.getSystemAuditLogs(limit: 50, offset: _systemLogs.length);
      // _systemLogs.addAll(newLogs);
      
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Gagal load more system logs: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}