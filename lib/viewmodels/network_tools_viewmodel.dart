import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/network_tool_model.dart';
import '../services/api_service.dart';

class NetworkToolsViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  NetworkToolType _selectedTool = NetworkToolType.ping;
  final Map<NetworkToolType, String> _inputs = {
    NetworkToolType.ping: '',
    NetworkToolType.traceroute: '',
    NetworkToolType.ipScan: '',
  };
  String _ipScanPrefix = '/24';

  bool _isRunning = false;
  NetworkToolType? _runningTool;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  CancelToken? _cancelToken;

  final Map<NetworkToolType, NetworkToolResponse?> _latestResults = {};
  final Map<NetworkToolType, String?> _toolErrors = {};
  final List<NetworkToolResponse> _history = [];

  int _externalTargetRevision = 0;

  NetworkToolsViewModel(this._apiService);

  NetworkToolType get selectedTool => _selectedTool;
  String get currentInput => _inputs[_selectedTool] ?? '';
  String get ipScanPrefix => _ipScanPrefix;
  bool get isRunning => _isRunning;
  NetworkToolType? get runningTool => _runningTool;
  int get elapsedSeconds => _elapsedSeconds;
  int get externalTargetRevision => _externalTargetRevision;

  NetworkToolResponse? get currentResult => _latestResults[_selectedTool];
  String? get currentError => _toolErrors[_selectedTool];
  List<NetworkToolResponse> get history => List.unmodifiable(_history);

  String inputFor(NetworkToolType tool) => _inputs[tool] ?? '';

  /// Menghasilkan string target efektif yang dikirim ke backend
  String buildEffectiveTarget([NetworkToolType? tool]) {
    final activeTool = tool ?? _selectedTool;
    final raw = (_inputs[activeTool] ?? '').trim();
    if (activeTool != NetworkToolType.ipScan) {
      return raw;
    }
    if (raw.isEmpty) return '';
    if (raw.contains('/') || _ipScanPrefix.isEmpty) {
      return raw;
    }
    return '$raw$_ipScanPrefix';
  }

  void setSelectedTool(NetworkToolType tool) {
    if (_selectedTool == tool) return;
    _selectedTool = tool;
    notifyListeners();
  }

  void setInput(String value, {NetworkToolType? tool}) {
    final targetTool = tool ?? _selectedTool;
    _inputs[targetTool] = value;
    if (_toolErrors[targetTool] != null) {
      _toolErrors[targetTool] = null;
    }
    notifyListeners();
  }

  void setIpScanPrefix(String prefix) {
    if (_ipScanPrefix == prefix) return;
    _ipScanPrefix = prefix;
    if (_toolErrors[NetworkToolType.ipScan] != null) {
      _toolErrors[NetworkToolType.ipScan] = null;
    }
    notifyListeners();
  }

  /// Mengisi target dari halaman lain (mis. shortcut dari Target ICMP & TCP)
  void prepareExternalTarget(
    String targetHost, {
    NetworkToolType tool = NetworkToolType.ping,
  }) {
    final cleanHost = targetHost.trim();
    _selectedTool = tool;
    _inputs[tool] = cleanHost;
    _toolErrors[tool] = null;
    _externalTargetRevision++;
    notifyListeners();
  }

  void clearCurrentConsole() {
    _latestResults[_selectedTool] = null;
    _toolErrors[_selectedTool] = null;
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  void cancelExecution() {
    if (!_isRunning) return;
    _cancelToken?.cancel('Dibatalkan pengguna');
  }

  /// Menjalankan utilitas aktif (Ping / Traceroute / IP Scan).
  /// Mengembalikan pesan peringatan bila terjadi validasi gagal (HTTP 400 / client validation),
  /// atau `null` bila eksekusi selesai tanpa error validasi.
  Future<({bool ok, String? feedbackMessage, bool isWarning})> executeCurrentTool() async {
    if (_isRunning) {
      return (
        ok: false,
        feedbackMessage: 'Tunggu proses ${_runningTool?.label ?? "utilitas"} selesai atau tekan Batalkan.',
        isWarning: true,
      );
    }

    final tool = _selectedTool;
    final effectiveTarget = buildEffectiveTarget(tool);

    final validationMsg = tool == NetworkToolType.ipScan
        ? NetworkToolValidator.validateIpScanTarget(effectiveTarget)
        : NetworkToolValidator.validateHostOrDomain(effectiveTarget);

    if (validationMsg != null) {
      _toolErrors[tool] = validationMsg;
      notifyListeners();
      return (ok: false, feedbackMessage: validationMsg, isWarning: true);
    }

    _isRunning = true;
    _runningTool = tool;
    _elapsedSeconds = 0;
    _toolErrors[tool] = null;
    final token = CancelToken();
    _cancelToken = token;

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();

    try {
      late final NetworkToolResponse res;
      switch (tool) {
        case NetworkToolType.ping:
          res = await _apiService.runPing(effectiveTarget, cancelToken: token);
          break;
        case NetworkToolType.traceroute:
          res = await _apiService.runTraceroute(
            effectiveTarget,
            cancelToken: token,
          );
          break;
        case NetworkToolType.ipScan:
          res = await _apiService.runIpScan(effectiveTarget, cancelToken: token);
          break;
      }

      _latestResults[tool] = res;
      if (!res.isValidationError) {
        _history.insert(0, res);
        if (_history.length > 15) {
          _history.removeLast();
        }
      }

      if (res.isValidationError) {
        final msg = res.message.isNotEmpty
            ? res.message
            : 'Format target tidak valid.';
        _toolErrors[tool] = msg;
        return (ok: false, feedbackMessage: msg, isWarning: true);
      }

      return (
        ok: res.success,
        feedbackMessage: res.message.isNotEmpty ? res.message : null,
        isWarning: !res.success,
      );
    } on ApiException catch (e) {
      if (e.isCancelled) {
        return (
          ok: false,
          feedbackMessage: 'Eksekusi ${tool.label} dibatalkan.',
          isWarning: true,
        );
      }
      _toolErrors[tool] = e.toString();
      return (ok: false, feedbackMessage: e.toString(), isWarning: false);
    } catch (e) {
      final errStr = e.toString();
      _toolErrors[tool] = errStr;
      return (ok: false, feedbackMessage: errStr, isWarning: false);
    } finally {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _isRunning = false;
      _runningTool = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _cancelToken?.cancel('ViewModel disposed');
    super.dispose();
  }
}
