import 'dart:io' show HttpClient, Platform, X509Certificate;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/alert_incident_model.dart';
import '../models/analytics_model.dart';
import '../models/dashboard_model.dart';
import '../models/log_model.dart';
import '../models/network_target_model.dart';
import '../models/proxmox_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ViewMoxApiService {
  final StorageService _storageService;
  late final Dio _dio;
  void Function(int statusCode, String message)? onUnauthorizedOrForbidden;

  ViewMoxApiService(this._storageService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: StorageService.defaultBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Izinkan self-signed HTTPS certificate untuk IP/Domain lokal maupun publik
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipBaseUrlOverride'] != true) {
            final currentBaseUrl = await _storageService.getBaseUrl();
            options.baseUrl = currentBaseUrl;
          }

          if (!options.path.contains('/auth/login')) {
            final token = await _storageService.getApiToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Fallback otomatis localhost <-> 10.0.2.2 di Android Emulator / Device
          if (!kIsWeb &&
              Platform.isAndroid &&
              e.requestOptions.extra['retriedLocalhost'] != true &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.connectionTimeout)) {
            final origBase = e.requestOptions.baseUrl;
            String? altBase;
            if (origBase.contains('://localhost') ||
                origBase.contains('://127.0.0.1')) {
              altBase = origBase
                  .replaceFirst('://localhost', '://10.0.2.2')
                  .replaceFirst('://127.0.0.1', '://10.0.2.2');
            } else if (origBase.contains('://10.0.2.2')) {
              altBase = origBase.replaceFirst('://10.0.2.2', '://localhost');
            }

            if (altBase != null) {
              try {
                final retryOpts = e.requestOptions.copyWith(
                  baseUrl: altBase,
                  extra: {
                    ...e.requestOptions.extra,
                    'retriedLocalhost': true,
                    'skipBaseUrlOverride': true,
                  },
                );
                final response = await _dio.fetch(retryOpts);
                return handler.resolve(response);
              } catch (_) {
                // Lanjutkan ke error asli bila fallback juga gagal
              }
            }
          }

          final status = e.response?.statusCode;
          if ((status == 401 || status == 403) &&
              !e.requestOptions.path.contains('/auth/login')) {
            final msg = _extractErrorMessage(e);
            await _storageService.clearSession();
            onUnauthorizedOrForbidden?.call(status!, msg);
          }
          return handler.next(e);
        },
      ),
    );
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    switch (e.response?.statusCode) {
      case 400:
        return 'Permintaan tidak valid (400 Bad Request).';
      case 401:
        return 'Sesi berakhir atau Token tidak valid (401 Unauthorized).';
      case 403:
        return 'Akun dinonaktifkan atau akses ditolak (403 Forbidden).';
      case 404:
        return 'Endpoint atau data tidak ditemukan (404 Not Found).';
      case 500:
        return 'Terjadi kesalahan pada server ViewMox (500 Internal Error).';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      final detail = e.error?.toString() ?? e.message ?? '';
      return 'Gagal terhubung ke server ViewMox (${e.requestOptions.baseUrl}). ${detail.isNotEmpty ? "\nDetail: $detail" : "Periksa jaringan atau URL server."}';
    }
    return e.message ?? 'Terjadi kesalahan jaringan.';
  }

  Never _throwHandled(Object e) {
    if (e is DioException) {
      throw ApiException(_extractErrorMessage(e), statusCode: e.response?.statusCode);
    }
    if (e is ApiException) throw e;
    throw ApiException(e.toString());
  }

  // ===========================================================================
  // A. MODUL OTENTIKASI & SESI
  // ===========================================================================

  /// 1. POST /api/mobile/v1/auth/login
  Future<UserModel> login({
    required String username,
    required String password,
    required String token,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
          'token': token.trim(),
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw ApiException(body['message']?.toString() ?? 'Login gagal.');
      }
      final user = UserModel.fromJson(body['data'] as Map<String, dynamic>);
      final savedToken = (user.apiToken != null && user.apiToken!.isNotEmpty)
          ? user.apiToken!
          : token.trim();
      await _storageService.saveApiToken(savedToken);
      await _storageService.saveCachedUser(user);
      return user;
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 2. GET /api/mobile/v1/auth/me
  Future<UserModel> getMe() async {
    try {
      final res = await _dio.get('/auth/me');
      final body = res.data as Map<String, dynamic>;
      final user = UserModel.fromJson(body['data'] as Map<String, dynamic>);
      await _storageService.saveCachedUser(user);
      return user;
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // B. MODUL DASHBOARD & STATUS GLOBAL
  // ===========================================================================

  /// 3. GET /api/mobile/v1/system/status
  Future<SystemStatusModel> getSystemStatus() async {
    try {
      final res = await _dio.get('/system/status');
      final body = res.data as Map<String, dynamic>;
      return SystemStatusModel.fromJson(
        (body['data'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 4. GET /api/mobile/v1/dashboard?timeframe=1h
  Future<DashboardSummaryModel> getDashboardSummary({String timeframe = '1h'}) async {
    try {
      final res = await _dio.get(
        '/dashboard',
        queryParameters: {'timeframe': timeframe},
      );
      final body = res.data as Map<String, dynamic>;
      return DashboardSummaryModel.fromJson(
        (body['data'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // C. MODUL ALERT & PENANGANAN INSIDEN (TICKETING)
  // ===========================================================================

  /// 5. GET /api/mobile/v1/alerts/active
  Future<List<AlertModel>> getActiveAlerts() async {
    try {
      final res = await _dio.get('/alerts/active');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 6. GET /api/mobile/v1/alerts/history?limit=100
  Future<List<AlertModel>> getAlertHistory({int limit = 100}) async {
    try {
      final res = await _dio.get(
        '/alerts/history',
        queryParameters: {'limit': limit},
      );
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 7. POST /api/mobile/v1/alerts/join (dan alias /incidents/join)
  Future<String> joinAlert(int alertId) async {
    try {
      final res = await _dio.post(
        '/alerts/join',
        data: {'alert_id': alertId},
      );
      final body = res.data as Map<String, dynamic>;
      return body['message']?.toString() ??
          'Berhasil bergabung dalam penanganan tiket';
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 8. POST /api/mobile/v1/alerts/resolve (dan alias /incidents/resolve)
  Future<String> resolveAlert(int alertId) async {
    try {
      final res = await _dio.post(
        '/alerts/resolve',
        data: {'alert_id': alertId},
      );
      final body = res.data as Map<String, dynamic>;
      return body['message']?.toString() ?? 'Tiket berhasil ditandai selesai';
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 9. GET /api/mobile/v1/incidents
  Future<List<IncidentTicketModel>> getIncidents() async {
    try {
      final res = await _dio.get('/incidents');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => IncidentTicketModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 9b. GET /api/mobile/v1/incidents/stats
  Future<IncidentStatsModel> getIncidentStats() async {
    try {
      final res = await _dio.get('/incidents/stats');
      final body = res.data as Map<String, dynamic>;
      return IncidentStatsModel.fromJson(
        (body['data'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // D. MODUL ANALITIK SLA (ITIL)
  // ===========================================================================

  /// 10. GET /api/mobile/v1/analytics?period=24h&severity=ALL
  Future<SlaAnalyticsResponseModel> getAnalytics({
    String period = '24h',
    String severity = 'ALL',
  }) async {
    try {
      final res = await _dio.get(
        '/analytics',
        queryParameters: {
          'period': period,
          'severity': severity,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return SlaAnalyticsResponseModel.fromJson(body);
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // E. MODUL MONITORING NETWORK (ICMP PING & TCP SOCKET)
  // ===========================================================================

  /// 11. GET /api/mobile/v1/targets
  Future<List<NetworkTargetModel>> getTargets() async {
    try {
      final res = await _dio.get('/targets');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => NetworkTargetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 12. GET /api/mobile/v1/targets/:id/history
  Future<List<TargetLatencyPointModel>> getTargetHistory(int targetId) async {
    try {
      final res = await _dio.get('/targets/$targetId/history');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => TargetLatencyPointModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // F. MODUL MONITORING PROXMOX VE
  // ===========================================================================

  /// 13. GET /api/mobile/v1/proxmox
  Future<List<ProxmoxServerModel>> getProxmoxServers() async {
    try {
      final res = await _dio.get('/proxmox');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => ProxmoxServerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 14. GET /api/mobile/v1/proxmox/:id/status
  Future<List<ProxmoxNodeStatusModel>> getProxmoxNodeStatus(int serverId) async {
    try {
      final res = await _dio.get('/proxmox/$serverId/status');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => ProxmoxNodeStatusModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 15. GET /api/mobile/v1/proxmox/:id/resources
  Future<ProxmoxResourcesBundle> getProxmoxResources(int serverId) async {
    try {
      final res = await _dio.get('/proxmox/$serverId/resources');
      final body = res.data as Map<String, dynamic>;
      return ProxmoxResourcesBundle.fromJson(
        (body['data'] as Map<String, dynamic>?) ?? const {},
      );
    } catch (e) {
      _throwHandled(e);
    }
  }

  // ===========================================================================
  // G. MODUL LOG & AUDIT TERPADU
  // ===========================================================================

  /// 16. GET /api/mobile/v1/proxmox/logs/tasks
  Future<List<ProxmoxTaskLogModel>> getProxmoxTaskLogs() async {
    try {
      final res = await _dio.get('/proxmox/logs/tasks');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => ProxmoxTaskLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 17. GET /api/mobile/v1/proxmox/logs/cluster
  Future<List<ProxmoxClusterLogModel>> getProxmoxClusterLogs() async {
    try {
      final res = await _dio.get('/proxmox/logs/cluster');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => ProxmoxClusterLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 18. GET /api/mobile/v1/proxmox/logs/task-detail?node=...&upid=...
  Future<List<String>> getProxmoxTaskDetail({
    required String node,
    required String upid,
  }) async {
    try {
      final res = await _dio.get(
        '/proxmox/logs/task-detail',
        queryParameters: {'node': node, 'upid': upid},
      );
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list.map((e) {
        if (e is Map<String, dynamic>) {
          return e['t']?.toString() ?? '';
        }
        return e.toString();
      }).toList();
    } catch (e) {
      _throwHandled(e);
    }
  }

  /// 19. GET /api/mobile/v1/logs/system?limit=200
  Future<List<SystemAuditLogModel>> getSystemAuditLogs({int limit = 200}) async {
    try {
      final res = await _dio.get(
        '/logs/system',
        queryParameters: {'limit': limit},
      );
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? const [];
      return list
          .map((e) => SystemAuditLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _throwHandled(e);
    }
  }
}
