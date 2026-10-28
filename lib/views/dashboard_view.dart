import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/alert_incident_model.dart';
import '../models/dashboard_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'common_widgets.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback? onOpenIncidentsTab;
  final VoidCallback? onOpenResourceTab;
  final VoidCallback? onOpenAnalyticsTab;

  const DashboardView({
    super.key,
    this.onOpenIncidentsTab,
    this.onOpenResourceTab,
    this.onOpenAnalyticsTab,
  });

  // Adaptive theme colors
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _bgSurface => AppTheme.bgSurface;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;
  static Color get _textHint => AppTheme.textHint;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final vm = context.watch<DashboardViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final isKepalaBidang = authVm.isKepalaBidang;

    if (vm.isLoading && vm.summary == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2.5),
      );
    }

    if (vm.errorMessage != null && vm.summary == null) {
      return ErrorStateBox(
        message: vm.errorMessage!,
        onRetry: () => vm.fetchDashboard(showLoading: true),
      );
    }

    final summary = vm.summary;
    if (summary == null) return const SizedBox.shrink();

    if (isKepalaBidang) {
      return _buildKepalaBidangDashboard(context, vm, summary);
    }

    return RefreshIndicator(
      color: AppTheme.statusTeal,
      backgroundColor: _bgCard,
      onRefresh: () async {
        final analyticsVm = context.read<AnalyticsViewModel>();
        await Future.wait([
          vm.fetchDashboard(showLoading: false),
          analyticsVm.fetchAnalytics(showLoading: false),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const SectionTitle(
            title: 'KESEHATAN CLUSTER PROXMOX',
            icon: Icons.dns_rounded,
          ),
          const SizedBox(height: 12),
          _buildProxmoxOverviewCard(context, vm, summary.proxmox),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'TARGET JARINGAN (ICMP & TCP)',
            icon: Icons.lan_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildProtocolCard(
                  title: 'ICMP PING',
                  icon: Icons.network_ping_rounded,
                  data: summary.icmp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProtocolCard(
                  title: 'TCP SOCKET',
                  icon: Icons.settings_ethernet_rounded,
                  data: summary.tcp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'INSIDEN TERBARU',
            icon: Icons.notification_important_rounded,
            trailing: onOpenIncidentsTab != null
                ? _buildSectionAction('LIHAT SEMUA', onOpenIncidentsTab!)
                : null,
          ),
          const SizedBox(height: 12),
          if (summary.recentIncidents.isEmpty)
            _buildNoIncidentsCard()
          else
            ...summary.recentIncidents.map(_buildRecentIncidentTile),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildKepalaBidangDashboard(
    BuildContext context,
    DashboardViewModel vm,
    DashboardSummaryModel summary,
  ) {
    final alertVm = context.watch<AlertIncidentViewModel>();
    final analyticsVm = context.watch<AnalyticsViewModel>();
    final stats = alertVm.incidentStats;
    final slaSummary = analyticsVm.analytics?.summary;
    final unhandledCount = alertVm.activeAlerts.where((a) => !a.isBeingHandled).length;

    return RefreshIndicator(
      color: AppTheme.statusTeal,
      backgroundColor: _bgCard,
      onRefresh: () async {
        await Future.wait([
          vm.fetchDashboard(showLoading: false),
          alertVm.fetchAll(showLoading: false),
          analyticsVm.fetchAnalytics(showLoading: false),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          SectionTitle(
            title: 'RINGKASAN EKSEKUTIF',
            icon: Icons.verified_user_outlined,
            trailing: onOpenAnalyticsTab != null
                ? _buildSectionAction('DETAIL', onOpenAnalyticsTab!)
                : null,
          ),
          const SizedBox(height: 12),
          _buildExecutiveBannerCard(
            systemStatus: vm.systemStatus,
            summary: summary,
            stats: stats,
            availability: slaSummary?.availability,
            mttrSec: slaSummary?.mttrSec,
          ),
          const SizedBox(height: 24),
          SectionTitle(
            title: 'PENANGANAN GANGGUAN',
            icon: Icons.assignment_late_outlined,
            trailing: onOpenIncidentsTab != null
                ? _buildSectionAction('BUKA REKAP', onOpenIncidentsTab!)
                : null,
          ),
          const SizedBox(height: 12),
          _buildExecutiveIncidentEvaluationCard(
            stats: stats,
            unhandledCount: unhandledCount,
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'KINERJA PENANGANAN TEKNISI',
            icon: Icons.engineering_rounded,
          ),
          const SizedBox(height: 12),
          _buildTechnicianPerformanceCard(
            incidents: alertVm.incidents,
            activeUsers: summary.activeUsers,
            totalUsers: summary.totalUsers,
          ),
          const SizedBox(height: 24),
          SectionTitle(
            title: 'RESOURCE',
            icon: Icons.hub_rounded,
            trailing: onOpenResourceTab != null
                ? _buildSectionAction('DETAIL RESOURCE', onOpenResourceTab!)
                : null,
          ),
          const SizedBox(height: 12),
          _buildExecutiveResourceCard(context, vm, summary),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'INSIDEN TERBARU',
            icon: Icons.notification_important_rounded,
            trailing: onOpenIncidentsTab != null
                ? _buildSectionAction('LIHAT SEMUA', onOpenIncidentsTab!)
                : null,
          ),
          const SizedBox(height: 12),
          if (summary.recentIncidents.isEmpty)
            _buildNoIncidentsCard()
          else
            ...summary.recentIncidents.take(5).map(_buildRecentIncidentTile),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionAction(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.statusTeal,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppTheme.statusTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoIncidentsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.statusTeal,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              'Tidak ada insiden terbaru.\nSeluruh sistem beroperasi normal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveBannerCard({
    required SystemStatusModel? systemStatus,
    required DashboardSummaryModel summary,
    required IncidentStatsModel stats,
    required double? availability,
    required int? mttrSec,
  }) {
    final bool hasActiveAlert = stats.totalActive > 0;
    final bool hasCriticalOrDown = hasActiveAlert && (stats.down > 0 || stats.critical > 0);

    final Color statusColor = hasCriticalOrDown
        ? AppTheme.statusDown
        : (hasActiveAlert ? AppTheme.statusWarning : AppTheme.statusTeal);
    final String headline = hasCriticalOrDown
        ? 'PERHATIAN: ${stats.down + stats.critical} GANGGUAN KRITIS/DOWN'
        : (hasActiveAlert ? 'TERDAPAT ${stats.totalActive} PERINGATAN AKTIF' : 'SELURUH LAYANAN BEROPERASI NORMAL');

    final double availVal = availability ?? 100.0;
    final Color availColor = availVal >= 99.0
        ? AppTheme.statusTeal
        : (availVal >= 95.0 ? AppTheme.statusWarning : AppTheme.statusDown);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.08),
            _bgCard,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasActiveAlert ? Icons.radar_rounded : Icons.verified_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kesehatan Cluster ${summary.proxmox.healthPercent.toStringAsFixed(0)}% • ${summary.activeUsers}/${summary.totalUsers} Personel Aktif',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (systemStatus != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSystemPillarPill('PROXMOX', systemStatus.proxmox),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSystemPillarPill('ICMP PING', systemStatus.icmp),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSystemPillarPill('TCP SOCKET', systemStatus.tcp),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: _borderSubtle, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _buildExecutiveKpiTile(
                  label: 'KETERSEDIAAN',
                  value: '${availVal.toStringAsFixed(2)}%',
                  subtitle: availVal >= 99.0 ? 'Target ≥99% Tercapai' : 'Di Bawah Target SLA',
                  color: availColor,
                  icon: Icons.verified_user_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildExecutiveKpiTile(
                  label: 'RATA-RATA MTTR',
                  value: Formatters.formatDurationSeconds(mttrSec ?? 0),
                  subtitle: 'Kecepatan pemulihan',
                  color: AppTheme.statusRecovered,
                  icon: Icons.restore_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemPillarPill(String label, String status) {
    final color = AppTheme.severityColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveKpiTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: _textMain,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: _textMuted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveIncidentEvaluationCard({
    required IncidentStatsModel stats,
    required int unhandledCount,
  }) {
    final double resolutionRate = stats.totalTickets > 0
        ? (stats.resolved / stats.totalTickets * 100.0).clamp(0.0, 100.0)
        : 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernProgressBar(
            label: 'Rasio Penyelesaian Tiket',
            percentage: resolutionRate,
            color: AppTheme.statusTeal,
            customTrailingText:
                '${stats.resolved}/${stats.totalTickets} Selesai (${resolutionRate.toStringAsFixed(0)}%)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildIncidentMetricBox(
                  label: 'GANGGUAN AKTIF',
                  count: stats.totalActive,
                  color: stats.totalActive > 0 ? AppTheme.statusDown : AppTheme.statusTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIncidentMetricBox(
                  label: 'BELUM DIRESPON',
                  count: unhandledCount,
                  color: unhandledCount > 0 ? AppTheme.statusWarning : _textHint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIncidentMetricBox(
                  label: 'DALAM PROGRES',
                  count: stats.progress,
                  color: AppTheme.statusRecovered,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildIncidentMetricBox(
                  label: 'SELESAI',
                  count: stats.resolved,
                  color: AppTheme.statusTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentMetricBox({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianPerformanceCard({
    required List<IncidentTicketModel> incidents,
    required int activeUsers,
    required int totalUsers,
  }) {
    final Map<String, ({int total, int resolved, int active})> techMap = {};

    for (final inc in incidents) {
      final raw = inc.technicians?.trim() ?? '';
      if (raw.isEmpty || raw == '-') continue;

      final names = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != '-');

      for (final name in names) {
        final prev = techMap[name] ?? (total: 0, resolved: 0, active: 0);
        techMap[name] = (
          total: prev.total + 1,
          resolved: prev.resolved + (inc.isResolved ? 1 : 0),
          active: prev.active + (inc.isResolved ? 0 : 1),
        );
      }
    }

    final entries = techMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Penyelesaian Tim',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusBadge(
                label: '$activeUsers/$totalUsers Personel Aktif',
                color: AppTheme.statusTeal,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada riwayat penugasan teknisi pada tiket insiden.',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            )
          else
            ...entries.take(5).map((entry) {
              final name = entry.key;
              final stat = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderSubtle),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppTheme.statusTeal.withValues(alpha: 0.15),
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.statusTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: _textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stat.resolved} Selesai • ${stat.active} Sedang Ditangani',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.statusTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.statusTeal.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '${stat.total} Tiket',
                          style: const TextStyle(
                            color: AppTheme.statusTeal,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExecutiveResourceCard(
    BuildContext context,
    DashboardViewModel vm,
    DashboardSummaryModel summary,
  ) {
    final pve = summary.proxmox;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      'Node Online',
                      '${pve.onlineNodes}/${pve.totalNodes}',
                      Icons.dns_rounded,
                      AppTheme.statusTeal,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: _borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      'VM & LXC Aktif',
                      '${pve.runningVms}/${pve.totalVms}',
                      Icons.computer_rounded,
                      AppTheme.statusRecovered,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: _borderSubtle, height: 1),
              ),
              ModernProgressBar(
                label: 'Rata-rata Utilisasi CPU Cluster',
                percentage: pve.avgCpu,
                color: Colors.blue, // Explicitly blue for visibility in light theme
              ),
              const SizedBox(height: 14),
              ModernProgressBar(
                label: 'Rata-rata Utilisasi RAM Cluster',
                percentage: pve.avgRam,
                color: AppTheme.statusTeal,
              ),
              const SizedBox(height: 14),
              ModernProgressBar(
                label: 'Rata-rata IO Delay',
                percentage: pve.avgIo,
                color: AppTheme.statusWarning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildProtocolCard(
                title: 'ICMP PING',
                icon: Icons.network_ping_rounded,
                data: summary.icmp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProtocolCard(
                title: 'TCP SOCKET',
                icon: Icons.settings_ethernet_rounded,
                data: summary.tcp,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProxmoxOverviewCard(
    BuildContext context,
    DashboardViewModel vm,
    DashboardProxmoxSummary pve,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Node Online',
                  '${pve.onlineNodes}/${pve.totalNodes}',
                  Icons.dns_rounded,
                  AppTheme.statusTeal,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: _borderSubtle,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildMiniStat(
                  'Guest Aktif',
                  '${pve.runningVms}/${pve.totalVms}',
                  Icons.computer_rounded,
                  AppTheme.statusRecovered,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: _borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Metrik Beban Cluster',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderSubtle),
                ),
                child: Row(
                  children: ['1h', '24h', '7d'].map((tf) {
                    final selected = vm.selectedTimeframe == tf;
                    return GestureDetector(
                      onTap: () => vm.fetchDashboard(showLoading: false, timeframe: tf),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.statusTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          tf.toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.white : _textMuted,
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              ChartLegendItem(color: Colors.blue, label: 'CPU %'),
              SizedBox(width: 16),
              ChartLegendItem(color: AppTheme.statusTeal, label: 'RAM %'),
              SizedBox(width: 16),
              ChartLegendItem(color: AppTheme.statusWarning, label: 'IO Delay %'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 185,
            child: _buildRrdChart(pve.chart),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: _textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRrdChart(DashboardChartModel chart) {
    if (chart.cpu.isEmpty && chart.ram.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data grafik RRD.',
          style: TextStyle(color: _textHint, fontSize: 12),
        ),
      );
    }

    List<FlSpot> toSpots(List<double> values) {
      return List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i].clamp(0.0, 100.0)),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return List.generate(touchedSpots.length, (i) {
                final spot = touchedSpots[i];
                final idx = spot.x.toInt();
                final timeLabel =
                    (idx >= 0 && idx < chart.labels.length) ? chart.labels[idx] : '';
                final barColor = spot.bar.color ?? Colors.blue;
                final metricName = barColor == AppTheme.statusTeal
                    ? 'RAM'
                    : (barColor == AppTheme.statusWarning ? 'IO' : 'CPU');
                final val = spot.y.toStringAsFixed(1);
                final prefix = (i == 0 && timeLabel.isNotEmpty) ? '$timeLabel\n' : '';
                return LineTooltipItem(
                  '$prefix$metricName: $val%',
                  TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                );
              });
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.gridLineColor,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: 25,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${val.toInt()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (chart.labels.length / 4).clamp(1, 20).toDouble(),
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= chart.labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    chart.labels[idx],
                    style: TextStyle(
                      color: _textHint,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          if (chart.cpu.isNotEmpty)
            LineChartBarData(
              spots: toSpots(chart.cpu),
              isCurved: true,
              curveSmoothness: 0.3,
              color: Colors.blue,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.withValues(alpha: 0.15),
                    Colors.blue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          if (chart.ram.isNotEmpty)
            LineChartBarData(
              spots: toSpots(chart.ram),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.statusTeal,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.statusTeal.withValues(alpha: 0.18),
                    AppTheme.statusTeal.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          if (chart.io.isNotEmpty)
            LineChartBarData(
              spots: toSpots(chart.io),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppTheme.statusWarning,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard({
    required String title,
    required IconData icon,
    required DashboardProtocolSummary data,
  }) {
    final hasDown = data.down > 0;
    final statusColor = hasDown ? AppTheme.statusDown : AppTheme.statusTeal;
    final statusText = hasDown ? '${data.down} DOWN' : 'UP';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDown ? AppTheme.statusDown.withValues(alpha: 0.4) : _borderSubtle,
        ),
        boxShadow: hasDown
            ? [BoxShadow(color: AppTheme.statusDown.withValues(alpha: 0.1), blurRadius: 10)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.up}/${data.active}',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              StatusBadge(
                label: statusText,
                color: statusColor,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Rata-rata Latency: ${data.avgLatencyMs.toStringAsFixed(1)} ms',
            style: TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIncidentTile(RecentIncidentModel inc) {
    final color = AppTheme.severityColor(inc.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle), // FIXED: Menggunakan _borderSubtle agar selaras dan bukan warna hijau/teal
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), // FIXED: Menggunakan warna shadow netral
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    inc.ticketId,
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: '${inc.severity.toUpperCase()} • ${inc.statusLabel.toUpperCase()}', // FIXED: Format string 1 baris
                color: color,
                showDot: false,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: _borderSubtle, height: 1),
          ),
          Text(
            inc.component.isNotEmpty ? inc.component : inc.targetName,
            style: TextStyle(
              color: _textMain,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            inc.message,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: _textHint),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDateTime(inc.time),
                    style: TextStyle(color: _textMuted, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: _textHint),
                  const SizedBox(width: 4),
                  Text(
                    inc.technicians.isNotEmpty && inc.technicians != '-'
                        ? inc.technicians
                        : 'Belum Ditangani',
                    style: TextStyle(
                      color: inc.technicians.isNotEmpty && inc.technicians != '-'
                          ? AppTheme.statusTeal
                          : AppTheme.statusWarning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}