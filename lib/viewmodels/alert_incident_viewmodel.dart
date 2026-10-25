import 'package:flutter/foundation.dart';
import '../models/alert_incident_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AlertIncidentViewModel extends ChangeNotifier {
  final ViewMoxApiService _apiService;
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
  IncidentStatsModel get incidentStats {
    if (_incidentStats != null) return _incidentStats!;
    int down = 0;
    int critical = 0;
    int warning = 0;
    int progress = 0;
    for (final a in _activeAlerts) {
      final sev = a.severity.toUpperCase();
      if (sev == 'DOWN') {
        down++;
      } else if (sev == 'CRITICAL') {
        critical++;
      } else if (sev == 'WARNING') {
        warning++;
      }
      if (a.isBeingHandled) {
        progress++;
      }
    }
    final resolved = _historyAlerts.length;
    final totalActive = _activeAlerts.length;
    return IncidentStatsModel(
      down: down,
      critical: critical,
      warning: warning,
      progress: progress,
      resolved: resolved,
      totalActive: totalActive,
      totalTickets: totalActive + resolved,
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
      _dismissedCallAlertIds.add(_pendingEmergencyCall!.id);
      _pendingEmergencyCall = null;
      notifyListeners();
    }
  }

  Future<void> pollActiveAlerts({bool triggerNotifications = true}) async {
    try {
      final latest = await _apiService.getActiveAlerts();
      for (final alert in latest) {
        final prevSeverity = _knownAlertSeverities[alert.id];
        final isNewOrChanged = prevSeverity == null || prevSeverity != alert.severity;
        _knownAlertSeverities[alert.id] = alert.severity;

        if (triggerNotifications && isNewOrChanged) {
          await _notificationService.showAlertNotification(alert);
          if (alert.isEmergencyCall &&
              !alert.isBeingHandled &&
              alert.severity.toUpperCase() != 'RECOVERED' &&
              !_dismissedCallAlertIds.contains(alert.id)) {
            _pendingEmergencyCall = alert;
          }
        }
      }

      // Bersihkan ID yang sudah tidak aktif
      final currentIds = latest.map((e) => e.id).toSet();
      _knownAlertSeverities.removeWhere((id, _) => !currentIds.contains(id));

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

      for (final a in _activeAlerts) {
        _knownAlertSeverities[a.id] = a.severity;
      }
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
      if (_pendingEmergencyCall?.id == alertId) {
        _dismissedCallAlertIds.add(alertId);
        _pendingEmergencyCall = null;
      }
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