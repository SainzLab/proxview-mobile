import 'dart:async';
import 'dart:ui'; // Tambahkan ini untuk ImageFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/alert_incident_model.dart';
import '../models/user_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/log_viewmodel.dart';
import '../viewmodels/network_viewmodel.dart';
import '../viewmodels/proxmox_viewmodel.dart';
import 'alerts_incidents_view.dart';
import 'emergency_call_view.dart';
import 'resource_view.dart';
import 'sla_analytics_view.dart';
import 'dashboard_view.dart';
import 'logs_view.dart';
import 'network_targets_view.dart';
import 'proxmox_view.dart';
import 'settings_view.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  bool? _lastIsKabid;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _pollTick = 0;
  Timer? _pollingTimer;
  late AnimationController _syncController;

  static const List<String> _teknisiTitles = [
    'Dashboard',
    'Alert & Tiket Insiden',
    'Cluster Proxmox',
    'Target ICMP & TCP',
    'Analitik',
    'Log & Audit Sistem',
    'Pengaturan',
  ];

  static const List<String> _kabidTitles = [
    'Dashboard',
    'Rekap Gangguan',
    'Resource',
    'Analitik',
    'Pengaturan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inisialisasi controller untuk animasi rotasi tombol reload
    _syncController = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _startBackgroundPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed && mounted) {
      final isKabid = context.read<AuthViewModel>().isKepalaBidang;
      context.read<AlertIncidentViewModel>().pollActiveAlerts(
        triggerNotifications: !isKabid,
      );
    }
  }

  void _loadInitialData() {
    if (!mounted) return;
    context.read<DashboardViewModel>().fetchDashboard(showLoading: true);
    context.read<AlertIncidentViewModel>().fetchAll(showLoading: true);
    context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: true);
    context.read<NetworkViewModel>().fetchTargets(showLoading: true);
    context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: true);
  }

  void _startBackgroundPolling() {
    _pollingTimer?.cancel();
    // Interval 12 detik (> receiveTimeout 8s) mencegah tumpukan request paralel
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || _lifecycleState != AppLifecycleState.resumed) return;
      _pollTick++;

      final isKabid = context.read<AuthViewModel>().isKepalaBidang;
      final refreshAlertsFull = isKabid
          ? (_selectedIndex == 0 || _selectedIndex == 1)
          : (_selectedIndex == 1);

      if (refreshAlertsFull) {
        // Satu panggilan terpadu tanpa duplikasi pollActiveAlerts + fetchAll
        context.read<AlertIncidentViewModel>().fetchAll(
          showLoading: false,
          triggerNotifications: !isKabid,
        );
      } else {
        context.read<AlertIncidentViewModel>().pollActiveAlerts(
          triggerNotifications: !isKabid,
        );
      }

      if (isKabid) {
        switch (_selectedIndex) {
          case 0:
            context.read<DashboardViewModel>().fetchDashboard(showLoading: false);
            if (_pollTick % 3 == 0) {
              context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
            }
            break;
          case 2:
            context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: false);
            context.read<NetworkViewModel>().fetchTargets(showLoading: false);
            break;
          case 3:
            context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
            break;
        }
      } else {
        switch (_selectedIndex) {
          case 0:
            context.read<DashboardViewModel>().fetchDashboard(showLoading: false);
            if (_pollTick % 3 == 0) {
              context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
            }
            break;
          case 2:
            context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: false);
            break;
          case 3:
            context.read<NetworkViewModel>().fetchTargets(showLoading: false);
            break;
          case 4:
            context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
            break;
          case 5:
            context.read<LogViewModel>().fetchLogs(showLoading: false);
            break;
        }
      }
    });
  }

  void _selectPage(int index) {
    final isKabid = context.read<AuthViewModel>().isKepalaBidang;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
    if (isKabid) {
      switch (index) {
        case 0:
          context.read<DashboardViewModel>().fetchDashboard(showLoading: false);
          context.read<AlertIncidentViewModel>().fetchAll(showLoading: false);
          context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
          break;
        case 1:
          context.read<AlertIncidentViewModel>().fetchAll(showLoading: false);
          break;
        case 2:
          context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: false);
          context.read<NetworkViewModel>().fetchTargets(showLoading: false);
          break;
        case 3:
          context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
          break;
      }
      return;
    }

    switch (index) {
      case 0:
        context.read<DashboardViewModel>().fetchDashboard(showLoading: false);
        context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
        break;
      case 1:
        context.read<AlertIncidentViewModel>().fetchAll(showLoading: false);
        break;
      case 2:
        context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: false);
        break;
      case 3:
        context.read<NetworkViewModel>().fetchTargets(showLoading: false);
        break;
      case 4:
        context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
        break;
      case 5:
        final logVm = context.read<LogViewModel>();
        final hasExistingLogs = logVm.taskLogs.isNotEmpty ||
            logVm.clusterLogs.isNotEmpty ||
            logVm.systemLogs.isNotEmpty;
        logVm.fetchLogs(showLoading: !hasExistingLogs);
        break;
    }
  }

  void _refreshCurrentPage() {
    // Jalankan animasi putar dari 0 hingga 1 (360 derajat)
    _syncController.forward(from: 0.0);
    _selectPage(_selectedIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final isDarkMode = context.select<ThemeViewModel, bool>(
      (vm) => vm.isDarkMode,
    );
    final isKabid = context.select<AuthViewModel, bool>(
      (vm) => vm.isKepalaBidang,
    );
    if (_lastIsKabid != isKabid) {
      _lastIsKabid = isKabid;
      _visitedTabs
        ..clear()
        ..add(0);
      if (_selectedIndex >= (isKabid ? _kabidTitles.length : _teknisiTitles.length)) {
        _selectedIndex = 0;
      }
    }

    final titles = isKabid ? _kabidTitles : _teknisiTitles;
    final settingsIndex = isKabid ? 4 : 6;
    final safeIndex = _selectedIndex >= titles.length ? 0 : _selectedIndex;
    _visitedTabs.add(safeIndex);

    final pendingCall = context.select<AlertIncidentViewModel, AlertModel?>(
      (vm) => vm.pendingEmergencyCall,
    );
    final activeAlertCount = context.select<AlertIncidentViewModel, int>(
      (vm) => vm.activeAlertCount,
    );

    // Jika ada Emergency Call aktif ("action_type" == "Call") untuk Teknisi, tampilkan layar alarm penuh
    if (!isKabid && pendingCall != null) {
      return EmergencyCallView(alert: pendingCall);
    }

    return Scaffold(
      backgroundColor: colors.bgMain,
      drawer: _buildDrawer(
        context,
        activeAlertCount,
        isKabid: isKabid,
        colors: colors,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.bgMain,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textMain),
        title: Row(
          children: [
            Expanded(
              child: Text(
                titles[safeIndex],
                style: TextStyle(
                  color: colors.textMain,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<ThemeViewModel>().toggleTheme(),
            tooltip: isDarkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDarkMode ? AppTheme.statusWarning : colors.textSecondary,
              size: 21,
            ),
          ),
          if (activeAlertCount > 0 && safeIndex != 1)
            IconButton(
              onPressed: () => _selectPage(1),
              icon: Badge(
                label: Text('$activeAlertCount', style: const TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.statusDown,
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.statusDown,
                ),
              ),
            ),
          if (safeIndex != settingsIndex)
            IconButton(
              onPressed: _refreshCurrentPage,
              icon: RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: _syncController,
                  curve: Curves.easeInOut,
                )),
                child: Icon(Icons.sync_rounded, color: colors.textSecondary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(isKabid: isKabid, safeIndex: safeIndex),
    );
  }

  Widget _buildBody({required bool isKabid, required int safeIndex}) {
    final tabCount = isKabid ? _kabidTitles.length : _teknisiTitles.length;
    return IndexedStack(
      index: safeIndex,
      children: List.generate(tabCount, (index) {
        if (!_visitedTabs.contains(index)) {
          return const SizedBox.shrink();
        }
        return _buildTabPage(isKabid: isKabid, index: index);
      }),
    );
  }

  Widget _buildTabPage({required bool isKabid, required int index}) {
    if (isKabid) {
      switch (index) {
        case 0:
          return DashboardView(
            onOpenIncidentsTab: () => _selectPage(1),
            onOpenResourceTab: () => _selectPage(2),
            onOpenAnalyticsTab: () => _selectPage(3),
          );
        case 1:
          return const AlertsIncidentsView();
        case 2:
          return const ResourceView();
        case 3:
          return const SlaAnalyticsView();
        case 4:
          return const SettingsView();
        default:
          return const SizedBox.shrink();
      }
    }

    switch (index) {
      case 0:
        return DashboardView(onOpenIncidentsTab: () => _selectPage(1));
      case 1:
        return const AlertsIncidentsView();
      case 2:
        return const ProxmoxView();
      case 3:
        return const NetworkTargetsView();
      case 4:
        return const SlaAnalyticsView();
      case 5:
        return const LogsView();
      case 6:
        return const SettingsView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    int activeAlerts, {
    required bool isKabid,
    required ProxViewThemeColors colors,
  }) {
    final user = context.select<AuthViewModel, UserModel?>(
      (vm) => vm.currentUser,
    );
    final userName = user?.name ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: colors.bgCard,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          // Drawer Header with very subtle light gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.statusTeal.withValues(alpha: 0.08),
                  colors.bgCard,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: colors.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trik UI: Drop Shadow Logo agar teks putih terbaca di light mode
                RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Layer 1: Shadow (Glow Gelap)
                      Transform.translate(
                        offset: const Offset(0, 1.5),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                          child: Image.asset(
                            'assets/diskominfosubang.png',
                            height: 56,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      // Layer 2: Original Logo
                      Image.asset(
                        'assets/diskominfosubang.png',
                        height: 56,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ProxView Monitoring Server Proxmox',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          
          // Drawer Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              physics: const BouncingScrollPhysics(),
              children: isKabid
                  ? [
                      _buildDrawerItem(
                        Icons.space_dashboard_rounded,
                        _kabidTitles[0],
                        0,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.assignment_late_rounded,
                        _kabidTitles[1],
                        1,
                        colors: colors,
                        badgeCount: activeAlerts,
                      ),
                      _buildDrawerItem(
                        Icons.hub_rounded,
                        _kabidTitles[2],
                        2,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.insert_chart_rounded,
                        _kabidTitles[3],
                        3,
                        colors: colors,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        child: Divider(color: colors.borderColor, height: 1),
                      ),
                      _buildDrawerItem(
                        Icons.settings_rounded,
                        _kabidTitles[4],
                        4,
                        colors: colors,
                      ),
                    ]
                  : [
                      _buildDrawerItem(
                        Icons.dashboard_customize_rounded,
                        _teknisiTitles[0],
                        0,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.crisis_alert_rounded,
                        _teknisiTitles[1],
                        1,
                        colors: colors,
                        badgeCount: activeAlerts,
                      ),
                      _buildDrawerItem(
                        Icons.dns_rounded,
                        _teknisiTitles[2],
                        2,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.router_rounded,
                        _teknisiTitles[3],
                        3,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.insert_chart_rounded,
                        _teknisiTitles[4],
                        4,
                        colors: colors,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        child: Divider(color: colors.borderColor, height: 1),
                      ),
                      _buildDrawerItem(
                        Icons.terminal_rounded,
                        _teknisiTitles[5],
                        5,
                        colors: colors,
                      ),
                      _buildDrawerItem(
                        Icons.settings_rounded,
                        _teknisiTitles[6],
                        6,
                        colors: colors,
                      ),
                    ],
            ),
          ),

          // Drawer Footer (User Info)
          if (user != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  border: Border(top: BorderSide(color: colors.borderColor)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.statusTeal.withValues(alpha: 0.15),
                      child: Text(
                        userInitial,
                        style: const TextStyle(
                          color: AppTheme.statusTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: colors.textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.statusTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.statusTeal,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    int index, {
    required ProxViewThemeColors colors,
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.statusTeal.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.statusTeal : colors.textHint,
          size: 21,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? colors.textMain : colors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusDown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.statusDown.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: AppTheme.statusDown,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context); // Tutup drawer
          if (!isSelected) {
            _selectPage(index);
          }
        },
      ),
    );
  }
}