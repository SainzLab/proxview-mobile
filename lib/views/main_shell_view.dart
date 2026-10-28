import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/log_viewmodel.dart';
import '../viewmodels/network_viewmodel.dart';
import '../viewmodels/proxmox_viewmodel.dart';
import 'alerts_incidents_view.dart';
import 'common_widgets.dart';
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

class _MainShellViewState extends State<MainShellView> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  Timer? _pollingTimer;
  late AnimationController _syncController;

  // Light Theme Specific Colors
  static const Color _bgMain = Color(0xFFF8F9FA); // slate-50
  static const Color _bgCard = Colors.white;
  static const Color _borderSubtle = Color(0xFFE2E8F0); // slate-200
  static const Color _textMain = Color(0xFF0F172A); // slate-900
  static const Color _textSecondary = Color(0xFF475569); // slate-600
  static const Color _textMuted = Color(0xFF64748B); // slate-500
  static const Color _textHint = Color(0xFF94A3B8); // slate-400

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
    _pollingTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;
      final isKabid = context.read<AuthViewModel>().isKepalaBidang;
      context.read<AlertIncidentViewModel>().pollActiveAlerts(
        triggerNotifications: !isKabid,
      );

      if (isKabid) {
        switch (_selectedIndex) {
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
      } else {
        switch (_selectedIndex) {
          case 0:
            context.read<DashboardViewModel>().fetchDashboard(showLoading: false);
            context.read<AnalyticsViewModel>().fetchAnalytics(showLoading: false);
            break;
          case 2:
            context.read<ProxmoxViewModel>().fetchProxmoxData(showLoading: false);
            break;
          case 3:
            context.read<NetworkViewModel>().fetchTargets(showLoading: false);
            break;
        }
      }
    });
  }

  void _selectPage(int index) {
    final isKabid = context.read<AuthViewModel>().isKepalaBidang;
    setState(() => _selectedIndex = index);
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
        context.read<LogViewModel>().fetchLogs(showLoading: true);
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
    _pollingTimer?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final isKabid = authVm.isKepalaBidang;
    final titles = isKabid ? _kabidTitles : _teknisiTitles;
    final settingsIndex = isKabid ? 4 : 6;
    final safeIndex = _selectedIndex >= titles.length ? 0 : _selectedIndex;

    final alertVm = context.watch<AlertIncidentViewModel>();
    final pendingCall = alertVm.pendingEmergencyCall;

    // Jika ada Emergency Call aktif ("action_type" == "Call") untuk Teknisi, tampilkan layar alarm penuh
    if (!isKabid && pendingCall != null) {
      return EmergencyCallView(alert: pendingCall);
    }

    return Scaffold(
      backgroundColor: _bgMain,
      drawer: _buildDrawer(context, alertVm.activeAlertCount, isKabid: isKabid),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgMain,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
        title: Row(
          children: [
            Expanded(
              child: Text(
                titles[safeIndex],
                style: const TextStyle(
                  color: _textMain,
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
          if (alertVm.activeAlertCount > 0 && safeIndex != 1)
            IconButton(
              onPressed: () => _selectPage(1),
              icon: Badge(
                label: Text('${alertVm.activeAlertCount}', style: const TextStyle(color: Colors.white)),
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
                child: const Icon(Icons.sync_rounded, color: _textSecondary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(isKabid: isKabid, safeIndex: safeIndex),
    );
  }

  Widget _buildBody({required bool isKabid, required int safeIndex}) {
    if (isKabid) {
      switch (safeIndex) {
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
          return DashboardView(
            onOpenIncidentsTab: () => _selectPage(1),
            onOpenResourceTab: () => _selectPage(2),
            onOpenAnalyticsTab: () => _selectPage(3),
          );
      }
    }

    switch (safeIndex) {
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
        return DashboardView(onOpenIncidentsTab: () => _selectPage(1));
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    int activeAlerts, {
    required bool isKabid,
  }) {
    final user = context.watch<AuthViewModel>().currentUser;
    final userName = user?.name ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: _bgCard,
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
                  _bgCard,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(bottom: BorderSide(color: _borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CustomPaint(
                          size: Size(36, 24),
                          painter: PulseLogoPainter(
                            color: AppTheme.statusTeal,
                            strokeWidth: 3.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ProxView',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MONITORING PROXMOX',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (user != null)
                  Row(
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
                              style: const TextStyle(
                                color: _textMain,
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
                      ),
                      _buildDrawerItem(
                        Icons.assignment_late_rounded,
                        _kabidTitles[1],
                        1,
                        badgeCount: activeAlerts,
                      ),
                      _buildDrawerItem(
                        Icons.hub_rounded,
                        _kabidTitles[2],
                        2,
                      ),
                      _buildDrawerItem(
                        Icons.insert_chart_rounded,
                        _kabidTitles[3],
                        3,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        child: Divider(color: _borderSubtle, height: 1),
                      ),
                      _buildDrawerItem(
                        Icons.settings_rounded,
                        _kabidTitles[4],
                        4,
                      ),
                    ]
                  : [
                      _buildDrawerItem(
                        Icons.dashboard_customize_rounded,
                        _teknisiTitles[0],
                        0,
                      ),
                      _buildDrawerItem(
                        Icons.crisis_alert_rounded,
                        _teknisiTitles[1],
                        1,
                        badgeCount: activeAlerts,
                      ),
                      _buildDrawerItem(
                        Icons.dns_rounded,
                        _teknisiTitles[2],
                        2,
                      ),
                      _buildDrawerItem(
                        Icons.router_rounded,
                        _teknisiTitles[3],
                        3,
                      ),
                      _buildDrawerItem(
                        Icons.insert_chart_rounded,
                        _teknisiTitles[4],
                        4,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        child: Divider(color: _borderSubtle, height: 1),
                      ),
                      _buildDrawerItem(
                        Icons.terminal_rounded,
                        _teknisiTitles[5],
                        5,
                      ),
                      _buildDrawerItem(
                        Icons.settings_rounded,
                        _teknisiTitles[6],
                        6,
                      ),
                    ],
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
          color: isSelected ? AppTheme.statusTeal : _textHint,
          size: 21,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? _textMain : _textSecondary,
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