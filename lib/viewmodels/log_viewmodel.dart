import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/log_model.dart';
import '../services/api_service.dart';

class LogViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  List<ProxmoxTaskLogModel> _taskLogs = [];
  List<ProxmoxClusterLogModel> _clusterLogs = [];
  List<SystemAuditLogModel> _systemLogs = [];

  bool _isLoading = false;
  bool _isFetching = false;
  bool _isTaskDetailLoading = false;
  bool _isLoadingMore = false;
  int _systemLogLimit = 200;
  bool _hasMoreSystemLogs = true;
  String? _errorMessage;
  String? _taskErrorMessage;
  String? _clusterErrorMessage;
  String? _systemErrorMessage;

  CancelToken? _fetchCancelToken;
  CancelToken? _detailCancelToken;

  LogViewModel(this._apiService);

  List<ProxmoxTaskLogModel> get taskLogs => _taskLogs;
  List<ProxmoxClusterLogModel> get clusterLogs => _clusterLogs;
  List<SystemAuditLogModel> get systemLogs => _systemLogs;
  bool get isLoading => _isLoading;
  bool get isTaskDetailLoading => _isTaskDetailLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreTasks => false;
  bool get hasMoreClusterLogs => false;
  bool get hasMoreSystemLogs => _hasMoreSystemLogs && _systemLogLimit < 500;
  String? get errorMessage => _errorMessage;
  String? get taskErrorMessage => _taskErrorMessage;
  String? get clusterErrorMessage => _clusterErrorMessage;
  String? get systemErrorMessage => _systemErrorMessage;

  Future<void> fetchLogs({bool showLoading = true}) async {
    if (!showLoading && _isFetching) return;

    if (showLoading) {
      _fetchCancelToken?.cancel('Refresh baru dimulai');
      _systemLogLimit = 200;
      _hasMoreSystemLogs = true;
      _isLoading = true;
      _errorMessage = null;
      _taskErrorMessage = null;
      _clusterErrorMessage = null;
      _systemErrorMessage = null;
      notifyListeners();
    }

    _isFetching = true;
    final token = CancelToken();
    _fetchCancelToken = token;

    try {
      final taskFuture = _apiService
          .getProxmoxTaskLogs(cancelToken: token)
          .then<List<ProxmoxTaskLogModel>>(
        (res) {
          _taskErrorMessage = null;
          return res;
        },
        onError: (err) {
          if (err is! DioException || err.type != DioExceptionType.cancel) {
            _taskErrorMessage = err.toString();
          }
          return <ProxmoxTaskLogModel>[];
        },
      );

      final clusterFuture = _apiService
          .getProxmoxClusterLogs(cancelToken: token)
          .then<List<ProxmoxClusterLogModel>>(
        (res) {
          _clusterErrorMessage = null;
          return res;
        },
        onError: (err) {
          if (err is! DioException || err.type != DioExceptionType.cancel) {
            _clusterErrorMessage = err.toString();
          }
          return <ProxmoxClusterLogModel>[];
        },
      );

      final systemFuture = _apiService
          .getSystemAuditLogs(
        limit: _systemLogLimit,
        cancelToken: token,
      )
          .then<List<SystemAuditLogModel>>(
        (res) {
          _systemErrorMessage = null;
          return res;
        },
        onError: (err) {
          if (err is! DioException || err.type != DioExceptionType.cancel) {
            _systemErrorMessage = err.toString();
          }
          return <SystemAuditLogModel>[];
        },
      );

      final results = await Future.wait([taskFuture, clusterFuture, systemFuture]);
      if (token.isCancelled) return;

      _taskLogs = results[0] as List<ProxmoxTaskLogModel>;
      _clusterLogs = results[1] as List<ProxmoxClusterLogModel>;
      _systemLogs = results[2] as List<SystemAuditLogModel>;
      _hasMoreSystemLogs =
          _systemLogs.length >= _systemLogLimit && _systemLogLimit < 500;

      // Hanya jadikan error global jika KETIGA modul log sama-sama gagal
      if (_taskLogs.isEmpty &&
          _clusterLogs.isEmpty &&
          _systemLogs.isEmpty &&
          (_taskErrorMessage != null ||
              _clusterErrorMessage != null ||
              _systemErrorMessage != null)) {
        _errorMessage = _systemErrorMessage ??
            _taskErrorMessage ??
            _clusterErrorMessage;
      } else {
        _errorMessage = null;
      }
    } catch (e) {
      if (showLoading ||
          (_taskLogs.isEmpty && _clusterLogs.isEmpty && _systemLogs.isEmpty)) {
        _errorMessage = e.toString();
      }
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> fetchTaskDetail({
    required String node,
    required String upid,
  }) async {
    _detailCancelToken?.cancel('Membuka detail task baru');
    final token = CancelToken();
    _detailCancelToken = token;

    _isTaskDetailLoading = true;
    notifyListeners();
    try {
      return await _apiService.getProxmoxTaskDetail(
        node: node,
        upid: upid,
        cancelToken: token,
      );
    } on ApiException catch (e) {
      if (e.isCancelled) return const [];
      return ['Gagal memuat detail task: $e'];
    } catch (e) {
      return ['Gagal memuat detail task: $e'];
    } finally {
      _isTaskDetailLoading = false;
      notifyListeners();
    }
  }

  // --- Fungsi Infinite Scroll / Load More ---

  Future<void> loadMoreTasks() async {
    // Endpoint /proxmox/tasks sudah mengembalikan seluruh task terbaru sekaligus.
    return;
  }

  Future<void> loadMoreClusterLogs() async {
    // Endpoint /proxmox/cluster-logs sudah mengembalikan log cluster sekaligus.
    return;
  }

  Future<void> loadMoreSystemLogs() async {
    if (_isLoadingMore || !hasMoreSystemLogs) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextLimit = (_systemLogLimit + 150).clamp(200, 500);
      final updated = await _apiService.getSystemAuditLogs(
        limit: nextLimit,
        cancelToken: _fetchCancelToken,
      );
      if (updated.length <= _systemLogs.length ||
          updated.length < nextLimit ||
          nextLimit >= 500) {
        _hasMoreSystemLogs = false;
      }
      _systemLogLimit = nextLimit;
      _systemLogs = updated;
    } on ApiException catch (e) {
      if (!e.isCancelled) {
        debugPrint('Gagal load more system logs: $e');
      }
    } catch (e) {
      debugPrint('Gagal load more system logs: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _fetchCancelToken?.cancel('ViewModel disposed');
    _detailCancelToken?.cancel('ViewModel disposed');
    super.dispose();
  }
}