import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'viewmodels/alert_incident_viewmodel.dart';
import 'viewmodels/analytics_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/log_viewmodel.dart';
import 'viewmodels/network_viewmodel.dart';
import 'viewmodels/proxmox_viewmodel.dart';
import 'views/login_view.dart';
import 'views/splash_view.dart';
import 'views/main_shell_view.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  if (data['action_type'] == 'Call') {
    final alertId = data['alert_id']?.toString() ?? '';
    final targetName = data['target_name']?.toString() ?? 'Monitoring Alert';
    final severity = data['severity']?.toString() ?? '';
    final alertMessage = data['message']?.toString() ?? '';

    final params = CallKitParams(
      id: alertId.isNotEmpty
          ? alertId
          : DateTime.now().millisecondsSinceEpoch.toString(),
      nameCaller: targetName,
      appName: 'ProxView',
      handle: alertMessage.isNotEmpty
          ? (severity.isNotEmpty ? '[$severity] $alertMessage' : alertMessage)
          : (severity.isNotEmpty ? 'Severity: $severity' : 'Incoming Call'),
      type: 0,
      duration: 30000,
      extra: <String, dynamic>{
        'alert_id': alertId,
        'target_name': targetName,
        'severity': severity,
        'message': alertMessage,
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed Call',
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Incoming Call',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StorageService _storageService;
  late final ProxViewApiService _apiService;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _apiService = ProxViewApiService(_storageService);
    _notificationService = NotificationService();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: _storageService),
        Provider<ProxViewApiService>.value(value: _apiService),
        ChangeNotifierProvider<ThemeViewModel>(
          create: (_) => ThemeViewModel(_storageService)..loadTheme(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) =>
              AuthViewModel(_apiService, _storageService)..initializeSession(),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (_) => DashboardViewModel(_apiService),
        ),
        ChangeNotifierProvider<AlertIncidentViewModel>(
          create: (_) =>
              AlertIncidentViewModel(_apiService, _notificationService),
        ),
        ChangeNotifierProvider<AnalyticsViewModel>(
          create: (_) => AnalyticsViewModel(_apiService),
        ),
        ChangeNotifierProvider<NetworkViewModel>(
          create: (_) => NetworkViewModel(_apiService),
        ),
        ChangeNotifierProvider<ProxmoxViewModel>(
          create: (_) => ProxmoxViewModel(_apiService),
        ),
        ChangeNotifierProvider<LogViewModel>(
          create: (_) => LogViewModel(_apiService),
        ),
      ],
      child: Selector<ThemeViewModel, ThemeMode>(
        selector: (_, themeVm) => themeVm.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'ProxView',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthViewModel, AuthStatus>((vm) => vm.status);
    switch (status) {
      case AuthStatus.checking:
        return const SplashView();
      case AuthStatus.unauthenticated:
        return const LoginView();
      case AuthStatus.authenticated:
        return const MainShellView();
    }
  }
}