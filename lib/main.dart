import 'dart:io';
import 'package:flutter/material.dart';
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

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final apiService = ViewMoxApiService(storageService);
    final notificationService = NotificationService();

    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<ViewMoxApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(apiService, storageService)..initializeSession(),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (_) => DashboardViewModel(apiService),
        ),
        ChangeNotifierProvider<AlertIncidentViewModel>(
          create: (_) => AlertIncidentViewModel(apiService, notificationService),
        ),
        ChangeNotifierProvider<AnalyticsViewModel>(
          create: (_) => AnalyticsViewModel(apiService),
        ),
        ChangeNotifierProvider<NetworkViewModel>(
          create: (_) => NetworkViewModel(apiService),
        ),
        ChangeNotifierProvider<ProxmoxViewModel>(
          create: (_) => ProxmoxViewModel(apiService),
        ),
        ChangeNotifierProvider<LogViewModel>(
          create: (_) => LogViewModel(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'ProxView',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _AuthGate(),
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