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
import 'emergency_call_view.dart';
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

// Tambahkan SingleTickerProviderStateMixin untuk animasi rotasi
class _MainShellViewState extends State<MainShellView> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  Timer? _pollingTimer;
  late AnimationController _syncController;

  static const List<String> _titles = [
    'Dashboard',
    'Alert & Tiket',
    'Proxmox Monitor',
    'ICMP & TCP Monitor',
    'Analitik',
    'Log & Audit',
    'Settings',
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
      context.read<AlertIncidentViewModel>().pollActiveAlerts();

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
    });
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
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
    final alertVm = context.watch<AlertIncidentViewModel>();
    final pendingCall = alertVm.pendingEmergencyCall;

    // Jika ada Emergency Call aktif ("action_type" == "Call"), tampilkan layar alarm penuh
    if (pendingCall != null) {
      return EmergencyCallView(alert: pendingCall);
    }

    return Scaffold(
      drawer: _buildDrawer(context, alertVm.activeAlertCount),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.background,
        title: Row(
          children: [
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (alertVm.activeAlertCount > 0 && _selectedIndex != 1)
            IconButton(
              onPressed: () => _selectPage(1),
              icon: Badge(
                label: Text('${alertVm.activeAlertCount}'),
                backgroundColor: AppTheme.statusDown,
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.statusDown,
                ),
              ),
            ),
          if (_selectedIndex != 6)
            IconButton(
              onPressed: _refreshCurrentPage,
              icon: RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: _syncController,
                  curve: Curves.easeInOut,
                )),
                child: const Icon(Icons.sync_rounded, color: Colors.white),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
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

  Widget _buildDrawer(BuildContext context, int activeAlerts) {
    final user = context.watch<AuthViewModel>().currentUser;
    final userName = user?.name ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: const Color(0xFF0B0D11), // Darker drawer background
      child: Column(
        children: [
          // Drawer Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 44, bottom: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.statusTeal.withValues(alpha: 0.2),
                  const Color(0xFF0B0D11),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
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
                        CustomPaint(
                          size: const Size(36, 24),
                          painter: const _PulseLogoPainter(
                            color: AppTheme.statusTeal,
                            strokeWidth: 3.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ProxView',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MONITORING PROXMOX',
                      style: TextStyle(
                        color: Color(0xFF94A3B8), // slate 400
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
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
                        backgroundColor: Colors.white10,
                        child: Text(
                          userInitial,
                          style: const TextStyle(
                            color: Colors.white,
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
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.statusTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.statusTeal,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
              children: [
                _buildDrawerItem(Icons.dashboard_customize, 'Dashboard', 0),
                _buildDrawerItem(
                  Icons.crisis_alert_rounded,
                  'Alert & Tiket Insiden',
                  1,
                  badgeCount: activeAlerts,
                ),
                _buildDrawerItem(Icons.storage_rounded, 'Proxmox VE', 2),
                _buildDrawerItem(Icons.router_rounded, 'Target ICMP & TCP', 3),
                _buildDrawerItem(Icons.insert_chart_rounded, 'Analitik', 4),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                
                _buildDrawerItem(Icons.terminal_rounded, 'Log & Audit Sistem', 5),
                _buildDrawerItem(Icons.settings_rounded, 'Settings', 6),
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
        color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.statusTeal : Colors.white54,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusDown.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.statusDown.withValues(alpha: 0.5)),
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

class _PulseLogoPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _PulseLogoPainter({
    required this.color,
    this.strokeWidth = 3.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    final baseY = h * 0.56;
    path.moveTo(0, baseY);
    path.lineTo(w * 0.18, baseY);
    path.lineTo(w * 0.40, h * 0.08);
    path.lineTo(w * 0.65, h * 0.94);
    path.lineTo(w * 0.82, baseY);
    path.lineTo(w, baseY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}