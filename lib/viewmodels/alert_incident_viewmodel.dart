import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_incident_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AlertIncidentViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;
  final NotificationService _notificationService;

  List<AlertModel> _activeAlerts = [];
  List<AlertModel> _historyAlerts = [];
  List<IncidentTicketModel> _incidents = [];
  IncidentStatsModel? _incidentStats;

  bool _isLoading = false;
  bool _isSubmittingAction = false;
  bool _isLoadingMore = false;
  bool _isPolling = false;
  bool _isFetchingAll = false;
  int _historyLimit = 100;
  bool _hasMoreHistoryAlerts = true;
  String? _errorMessage;

  CancelToken? _pollCancelToken;
  CancelToken? _fetchCancelToken;

  final Map<int, String> _knownAlertSeverities = {};
  final Set<int> _dismissedCallAlertIds = {};
  AlertModel? _pendingEmergencyCall;
  bool _hydratedFromNative = false;
  bool _pendingOpenAlertsTab = false;
  int? _targetEmergencyAlertId;

  AlertIncidentViewModel(this._apiService, this._notificationService);

  List<AlertModel> get activeAlerts => _activeAlerts;
  List<AlertModel> get historyAlerts => _historyAlerts;
  List<IncidentTicketModel> get incidents => _incidents;

  /// Perhitungan total insiden DOWN dari sisi frontend (akumulasi seluruh tiket/riwayat)
  int get totalDownCount {
    if (_incidents.isNotEmpty) {
      return _incidents.where((t) {
        final s = (t.originalSeverity.isNotEmpty &&
                t.originalSeverity.toUpperCase() != 'RECOVERED')
            ? t.originalSeverity.toUpperCase().trim()
            : t.severity.toUpperCase().trim();
        return s == 'DOWN';
      }).length;
    }
    final all = [..._activeAlerts, ..._historyAlerts];
    return all.where((a) {
      final s = (a.originalSeverity.isNotEmpty &&
              a.severity.toUpperCase() != 'RECOVERED')
          ? a.originalSeverity.toUpperCase().trim()
          : a.severity.toUpperCase().trim();
      return s == 'DOWN';
    }).length;
  }

  /// Perhitungan total insiden CRITICAL dari sisi frontend (akumulasi seluruh tiket/riwayat)
  int get totalCriticalCount {
    if (_incidents.isNotEmpty) {
      return _incidents.where((t) {
        final s = (t.originalSeverity.isNotEmpty &&
                t.originalSeverity.toUpperCase() != 'RECOVERED')
            ? t.originalSeverity.toUpperCase().trim()
            : t.severity.toUpperCase().trim();
        return s == 'CRITICAL';
      }).length;
    }
    final all = [..._activeAlerts, ..._historyAlerts];
    return all.where((a) {
      final s = (a.originalSeverity.isNotEmpty &&
              a.severity.toUpperCase() != 'RECOVERED')
          ? a.originalSeverity.toUpperCase().trim()
          : a.severity.toUpperCase().trim();
      return s == 'CRITICAL';
    }).length;
  }

  /// Perhitungan total insiden WARNING dari sisi frontend (akumulasi seluruh tiket/riwayat)
  int get totalWarningCount {
    if (_incidents.isNotEmpty) {
      return _incidents.where((t) {
        final s = (t.originalSeverity.isNotEmpty &&
                t.originalSeverity.toUpperCase() != 'RECOVERED')
            ? t.originalSeverity.toUpperCase().trim()
            : t.severity.toUpperCase().trim();
        return s == 'WARNING';
      }).length;
    }
    final all = [..._activeAlerts, ..._historyAlerts];
    return all.where((a) {
      final s = (a.originalSeverity.isNotEmpty &&
              a.severity.toUpperCase() != 'RECOVERED')
          ? a.originalSeverity.toUpperCase().trim()
          : a.severity.toUpperCase().trim();
      return s == 'WARNING';
    }).length;
  }

  IncidentStatsModel get incidentStats {
    final baseStats = _incidentStats;
    final totalDown = totalDownCount;
    final totalCrit = totalCriticalCount;
    final totalWarn = totalWarningCount;

    if (baseStats != null) {
      return IncidentStatsModel(
        down: baseStats.down,
        critical: baseStats.critical,
        warning: baseStats.warning,
        progress: baseStats.progress,
        resolved: baseStats.resolved,
        totalActive: baseStats.totalActive,
        totalTickets: baseStats.totalTickets,
        totalDown: totalDown,
        totalCritical: totalCrit,
        totalWarning: totalWarn,
      );
    }

    int activeDown = 0;
    int activeCrit = 0;
    int activeWarn = 0;
    int progress = 0;
    for (final a in _activeAlerts) {
      final sev = a.severity.toUpperCase();
      if (sev == 'DOWN') {
        activeDown++;
      } else if (sev == 'CRITICAL') {
        activeCrit++;
      } else if (sev == 'WARNING') {
        activeWarn++;
      }
      if (a.isBeingHandled) {
        progress++;
      }
    }
    final resolved = _historyAlerts.length;
    final totalActive = _activeAlerts.length;
    return IncidentStatsModel(
      down: activeDown,
      critical: activeCrit,
      warning: activeWarn,
      progress: progress,
      resolved: resolved,
      totalActive: totalActive,
      totalTickets: totalActive + resolved,
      totalDown: totalDown,
      totalCritical: totalCrit,
      totalWarning: totalWarn,
    );
  }
  bool get isLoading => _isLoading;
  bool get isSubmittingAction => _isSubmittingAction;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreActiveAlerts => false;
  bool get hasMoreIncidents => false;
  bool get hasMoreHistoryAlerts => _hasMoreHistoryAlerts && _historyLimit < 500;
  String? get errorMessage => _errorMessage;
  AlertModel? get pendingEmergencyCall => _pendingEmergencyCall;
  int get activeAlertCount => _activeAlerts.length;

  bool consumeOpenAlertsTabRequest() {
    final shouldOpen = _pendingOpenAlertsTab;
    _pendingOpenAlertsTab = false;
    return shouldOpen;
  }

  void setTargetEmergencyAlertId(int alertId) {
    _targetEmergencyAlertId = alertId;
    _dismissedCallAlertIds.remove(alertId);
    final existing = _activeAlerts.where((a) => a.id == alertId).firstOrNull;
    if (existing != null &&
        existing.isEmergencyCall &&
        !existing.isBeingHandled &&
        existing.severity.toUpperCase() != 'RECOVERED') {
      _pendingEmergencyCall = existing;
      notifyListeners();
    }
  }

  void dismissEmergencyCall() {
    if (_pendingEmergencyCall != null) {
      final dismissedId = _pendingEmergencyCall!.id;
      _dismissedCallAlertIds.add(dismissedId);
      _pendingEmergencyCall = null;
      _notificationService.stopEmergencyCall(dismissedId);
      _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
        overwriteKnown: false,
      );
      notifyListeners();
    }
  }

  /// Menandai panggilan darurat sebagai ditolak berdasarkan ID (mis. dari tombol "Tolak" CallKit),
  /// agar EmergencyCallView tidak muncul ulang untuk alert yang sama.
  void dismissEmergencyCallById(int alertId) {
    final added = _dismissedCallAlertIds.add(alertId);
    final wasPending = _pendingEmergencyCall?.id == alertId;
    if (wasPending) _pendingEmergencyCall = null;
    if (!added && !wasPending) return;
    _notificationService.stopEmergencyCall(alertId);
    _notificationService.syncAlertState(
      knownSeverities: _knownAlertSeverities,
      dismissedCallIds: _dismissedCallAlertIds,
      overwriteKnown: false,
    );
    notifyListeners();
  }

  Future<void> _syncNotificationsAndEmergencyState(
    List<AlertModel> latest, {
    required bool triggerNotifications,
  }) async {
    if (!_hydratedFromNative) {
      final init = await _notificationService.getInitialNotificationState();
      _hydratedFromNative = true;
      for (final entry in init.knownSeverities.entries) {
        _knownAlertSeverities.putIfAbsent(entry.key, () => entry.value);
      }
      _dismissedCallAlertIds.addAll(init.dismissedCallIds);
      if (init.emergencyAlertId != null && init.emergencyAlertId! > 0) {
        _targetEmergencyAlertId = init.emergencyAlertId;
        _dismissedCallAlertIds.remove(init.emergencyAlertId);
      }
      if (init.openAlertsTab) {
        _pendingOpenAlertsTab = true;
      }
    } else {
      final syncedDismissed = await _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
        overwriteKnown: false,
      );
      _dismissedCallAlertIds.addAll(syncedDismissed);
    }

    AlertModel? activeCallCandidate;
    final targetCallId = _targetEmergencyAlertId;
    _targetEmergencyAlertId = null;

    for (final alert in latest) {
      final prevSeverity = _knownAlertSeverities[alert.id];
      final isNewOrChanged =
          prevSeverity == null || prevSeverity != alert.severity;
      _knownAlertSeverities[alert.id] = alert.severity;

      final isUnhandledCall = alert.isEmergencyCall &&
          !alert.isBeingHandled &&
          alert.severity.toUpperCase() != 'RECOVERED' &&
          !_dismissedCallAlertIds.contains(alert.id);

      if (isUnhandledCall) {
        if (targetCallId != null && alert.id == targetCallId) {
          activeCallCandidate = alert;
        } else {
          activeCallCandidate ??= alert;
        }
      }

      if (triggerNotifications && isNewOrChanged) {
        await _notificationService.showAlertNotification(alert);
      }
    }

    if (triggerNotifications) {
      if (activeCallCandidate != null) {
        _pendingEmergencyCall = activeCallCandidate;
      } else if (_pendingEmergencyCall != null) {
        final prevCallId = _pendingEmergencyCall!.id;
        _pendingEmergencyCall = null;
        await _notificationService.stopEmergencyCall(prevCallId);
      }
    } else {
      _pendingEmergencyCall = activeCallCandidate;
    }

    final currentIds = latest.map((e) => e.id).toSet();
    _knownAlertSeverities.removeWhere((id, _) => !currentIds.contains(id));
    _dismissedCallAlertIds.retainAll(currentIds);

    await _notificationService.syncAlertState(
      knownSeverities: _knownAlertSeverities,
      dismissedCallIds: _dismissedCallAlertIds,
      overwriteKnown: true,
    );
  }

  Future<void> pollActiveAlerts({bool triggerNotifications = true}) async {
    if (_isPolling || _isFetchingAll) return;
    _isPolling = true;
    final token = CancelToken();
    _pollCancelToken = token;

    try {
      final latest = await _apiService.getActiveAlerts(cancelToken: token);

      await _syncNotificationsAndEmergencyState(
        latest,
        triggerNotifications: triggerNotifications,
      );

      _activeAlerts = latest;
      try {
        _incidentStats = await _apiService.getIncidentStats(cancelToken: token);
      } catch (_) {}
      notifyListeners();
    } catch (_) {
      // Abaikan error saat background polling
    } finally {
      _isPolling = false;
    }
  }

  Future<void> fetchAll({
    bool showLoading = true,
    bool triggerNotifications = false,
  }) async {
    if (!showLoading && _isFetchingAll) return;

    if (showLoading) {
      _fetchCancelToken?.cancel('Refresh baru dimulai');
      _historyLimit = 100;
      _hasMoreHistoryAlerts = true;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    _isFetchingAll = true;
    final token = CancelToken();
    _fetchCancelToken = token;

    try {
      final statsFuture = _apiService
          .getIncidentStats(cancelToken: token)
          .then<IncidentStatsModel?>((v) => v)
          .catchError((_) => null);

      final results = await Future.wait([
        _apiService.getActiveAlerts(cancelToken: token),
        _apiService.getAlertHistory(limit: _historyLimit, cancelToken: token),
        _apiService.getIncidents(cancelToken: token),
        statsFuture,
      ]);
      if (token.isCancelled) return;

      _activeAlerts = results[0] as List<AlertModel>;
      _historyAlerts = results[1] as List<AlertModel>;
      _incidents = results[2] as List<IncidentTicketModel>;
      _hasMoreHistoryAlerts =
          _historyAlerts.length >= _historyLimit && _historyLimit < 500;

      final fetchedStats = results[3] as IncidentStatsModel?;
      if (fetchedStats != null) {
        _incidentStats = fetchedStats;
      }

      await _syncNotificationsAndEmergencyState(
        _activeAlerts,
        triggerNotifications: triggerNotifications,
      );
      _errorMessage = null;
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (showLoading || (_activeAlerts.isEmpty && _incidents.isEmpty)) {
        _errorMessage = e.toString();
      }
    } catch (e) {
      if (showLoading || (_activeAlerts.isEmpty && _incidents.isEmpty)) {
        _errorMessage = e.toString();
      }
    } finally {
      _isFetchingAll = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool success, String message})> joinAlert(int alertId) async {
    _isSubmittingAction = true;
    notifyListeners();
    try {
      final msg = await _apiService.joinAlert(alertId);
      _dismissedCallAlertIds.add(alertId);
      if (_pendingEmergencyCall?.id == alertId) {
        _pendingEmergencyCall = null;
      }
      await _notificationService.stopEmergencyCall(alertId);
      await _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
      );
      await fetchAll(showLoading: false);
      return (success: true, message: msg);
    } catch (e) {
      return (success: false, message: e.toString());
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  Future<({bool success, String message})> resolveAlert(int alertId) async {
    _isSubmittingAction = true;
    notifyListeners();
    try {
      final msg = await _apiService.resolveAlert(alertId);
      await fetchAll(showLoading: false);
      return (success: true, message: msg);
    } catch (e) {
      return (success: false, message: e.toString());
    } finally {
      _isSubmittingAction = false;
      notifyListeners();
    }
  }

  // --- Fungsi Infinite Scroll / Load More ---

  Future<void> loadMoreActiveAlerts() async {
    // Endpoint /alerts/active sudah mengembalikan seluruh alert aktif sekaligus.
    return;
  }

  Future<void> loadMoreIncidents() async {
    // Endpoint /incidents sudah mengembalikan seluruh tiket insiden sekaligus.
    return;
  }

  Future<void> loadMoreHistoryAlerts() async {
    if (_isLoadingMore || !hasMoreHistoryAlerts) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextLimit = (_historyLimit + 100).clamp(100, 500);
      final updated = await _apiService.getAlertHistory(
        limit: nextLimit,
        cancelToken: _fetchCancelToken,
      );
      if (updated.length <= _historyAlerts.length ||
          updated.length < nextLimit ||
          nextLimit >= 500) {
        _hasMoreHistoryAlerts = false;
      }
      _historyLimit = nextLimit;
      _historyAlerts = updated;
    } on ApiException catch (e) {
      if (!e.isCancelled) {
        debugPrint('Gagal load more history alerts: $e');
      }
    } catch (e) {
      debugPrint('Gagal load more history alerts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollCancelToken?.cancel('ViewModel disposed');
    _fetchCancelToken?.cancel('ViewModel disposed');
    super.dispose();
  }
}