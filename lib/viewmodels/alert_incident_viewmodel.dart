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
  String? _errorMessage;

  final Map<int, String> _knownAlertSeverities = {};
  final Set<int> _dismissedCallAlertIds = {};
  AlertModel? _pendingEmergencyCall;

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
  String? get errorMessage => _errorMessage;
  AlertModel? get pendingEmergencyCall => _pendingEmergencyCall;
  int get activeAlertCount => _activeAlerts.length;

  void dismissEmergencyCall() {
    if (_pendingEmergencyCall != null) {
      final dismissedId = _pendingEmergencyCall!.id;
      _dismissedCallAlertIds.add(dismissedId);
      _pendingEmergencyCall = null;
      _notificationService.stopEmergencyCall(dismissedId);
      _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
      );
      notifyListeners();
    }
  }

  Future<void> pollActiveAlerts({bool triggerNotifications = true}) async {
    try {
      final latest = await _apiService.getActiveAlerts();

      // Sinkronkan daftar panggilan yang mungkin sudah ditutup lewat notifikasi bar Android
      final syncedDismissed = await _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
      );
      _dismissedCallAlertIds.addAll(syncedDismissed);

      AlertModel? activeCallCandidate;

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
          activeCallCandidate ??= alert;
        }

        if (triggerNotifications && isNewOrChanged) {
          await _notificationService.showAlertNotification(alert);
        }
      }

      // Tampilkan layar panggilan darurat apabila ada alert Call aktif yang belum ditangani
      if (triggerNotifications) {
        if (activeCallCandidate != null) {
          _pendingEmergencyCall = activeCallCandidate;
        } else if (_pendingEmergencyCall != null) {
          // Jika panggilan sebelumnya sudah ditangani atau sudah RECOVERED, matikan dering
          final prevCallId = _pendingEmergencyCall!.id;
          _pendingEmergencyCall = null;
          await _notificationService.stopEmergencyCall(prevCallId);
        }
      }

      // Bersihkan ID yang sudah tidak aktif
      final currentIds = latest.map((e) => e.id).toSet();
      _knownAlertSeverities.removeWhere((id, _) => !currentIds.contains(id));

      await _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
      );

      _activeAlerts = latest;
      try {
        _incidentStats = await _apiService.getIncidentStats();
      } catch (_) {}
      notifyListeners();
    } catch (_) {
      // Abaikan error saat background polling
    }
  }

  Future<void> fetchAll({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final statsFuture = _apiService
          .getIncidentStats()
          .then<IncidentStatsModel?>((v) => v)
          .catchError((_) => null);

      final results = await Future.wait([
        _apiService.getActiveAlerts(),
        _apiService.getAlertHistory(limit: 100),
        _apiService.getIncidents(),
        statsFuture,
      ]);
      _activeAlerts = results[0] as List<AlertModel>;
      _historyAlerts = results[1] as List<AlertModel>;
      _incidents = results[2] as List<IncidentTicketModel>;
      final fetchedStats = results[3] as IncidentStatsModel?;
      if (fetchedStats != null) {
        _incidentStats = fetchedStats;
      }

      final syncedDismissed = await _notificationService.syncAlertState(
        knownSeverities: _knownAlertSeverities,
        dismissedCallIds: _dismissedCallAlertIds,
      );
      _dismissedCallAlertIds.addAll(syncedDismissed);

      AlertModel? activeCallCandidate;
      for (final a in _activeAlerts) {
        _knownAlertSeverities[a.id] = a.severity;
        if (a.isEmergencyCall &&
            !a.isBeingHandled &&
            a.severity.toUpperCase() != 'RECOVERED' &&
            !_dismissedCallAlertIds.contains(a.id)) {
          activeCallCandidate ??= a;
        }
      }
      _pendingEmergencyCall = activeCallCandidate;
      _errorMessage = null;
    } catch (e) {
      if (showLoading || (_activeAlerts.isEmpty && _incidents.isEmpty)) {
        _errorMessage = e.toString();
      }
    } finally {
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
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda (contoh: offset)
      await Future.delayed(const Duration(seconds: 1)); // Simulasi proses loading
    } catch (e) {
      debugPrint('Gagal load more active alerts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreIncidents() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda (contoh: offset)
      await Future.delayed(const Duration(seconds: 1)); // Simulasi proses loading
    } catch (e) {
      debugPrint('Gagal load more incidents: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistoryAlerts() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // TODO: Ganti dengan pemanggilan API pagination Anda (contoh: offset)
      await Future.delayed(const Duration(seconds: 1)); // Simulasi proses loading
    } catch (e) {
      debugPrint('Gagal load more history alerts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}