import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/dashboard_model.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'common_widgets.dart';
import 'sla_analytics_view.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback? onOpenIncidentsTab;

  const DashboardView({super.key, this.onOpenIncidentsTab});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();

    if (vm.isLoading && vm.summary == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () async {
        final analyticsVm = context.read<AnalyticsViewModel>();
        await Future.wait([
          vm.fetchDashboard(showLoading: false),
          analyticsVm.fetchAnalytics(showLoading: false),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const HeaderGreeting(
            subtitle: 'Executive Overview',
            title: 'System Dashboard',
            showLiveIndicator: false,
          ),
          const SizedBox(height: 16),

          const SectionTitle(
            title: 'PROXMOX CLUSTER HEALTH',
            icon: Icons.dns_outlined,
          ),
          const SizedBox(height: 12),
          _buildProxmoxOverviewCard(context, vm, summary.proxmox),
          const SizedBox(height: 20),

          // Seksi Analitik Kinerja SLA (Uptime, Downtime, MTTR & Availability)
          const SlaMetricsSection(),
          const SizedBox(height: 20),

          const SectionTitle(
            title: 'NETWORK TARGETS (ICMP & TCP)',
            icon: Icons.lan_outlined,
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
                  icon: Icons.swap_horiz_rounded,
                  data: summary.tcp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SectionTitle(
            title: 'INSIDEN TERBARU',
            icon: Icons.notification_important_outlined,
            trailing: onOpenIncidentsTab != null
                ? TextButton(
                    onPressed: onOpenIncidentsTab,
                    child: const Text(
                      'LIHAT SEMUA',
                      style: TextStyle(
                        color: AppTheme.statusTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (summary.recentIncidents.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada insiden terbaru. Seluruh sistem normal.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            )
          else
            ...summary.recentIncidents.map(_buildRecentIncidentTile),

          const SizedBox(height: 40),
        ],
      ),
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
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nodes: ${pve.onlineNodes}/${pve.totalNodes} Online',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VM/LXC Running: ${pve.runningVms}/${pve.totalVms}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ModernProgressBar(
            label: 'Average CPU',
            percentage: pve.avgCpu,
            color: Colors.white,
          ),
          const SizedBox(height: 14),
          ModernProgressBar(
            label: 'Average RAM',
            percentage: pve.avgRam,
            color: AppTheme.statusTeal,
          ),
          const SizedBox(height: 14),
          ModernProgressBar(
            label: 'Average IO Delay',
            percentage: pve.avgIo,
            color: pve.avgIo > 5.0 ? AppTheme.statusCritical : AppTheme.statusWarning,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RRD CLUSTER METRICS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: ['1h', '24h', '7d'].map((tf) {
                  final selected = vm.selectedTimeframe == tf;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () => vm.fetchDashboard(showLoading: false, timeframe: tf),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tf.toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: _buildRrdChart(pve.chart),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.white, label: 'CPU %'),
              SizedBox(width: 16),
              _LegendDot(color: AppTheme.statusTeal, label: 'RAM %'),
              SizedBox(width: 16),
              _LegendDot(color: AppTheme.statusWarning, label: 'IO %'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRrdChart(DashboardChartModel chart) {
    if (chart.cpu.isEmpty && chart.ram.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data grafik RRD',
          style: TextStyle(color: Colors.white38, fontSize: 12),
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (val, _) => Text(
                '${val.toInt()}%',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (chart.labels.length / 4).clamp(1, 20).toDouble(),
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= chart.labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    chart.labels[idx],
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
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
              color: Colors.white,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          if (chart.ram.isNotEmpty)
            LineChartBarData(
              spots: toSpots(chart.ram),
              isCurved: true,
              color: AppTheme.statusTeal,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          if (chart.io.isNotEmpty)
            LineChartBarData(
              spots: toSpots(chart.io),
              isCurved: true,
              color: AppTheme.statusWarning,
              barWidth: 1.8,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDown
              ? AppTheme.statusDown.withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.up}/${data.active} UP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (hasDown)
                StatusBadge(label: '${data.down} DOWN', color: AppTheme.statusDown)
              else
                const StatusBadge(label: 'OK', color: AppTheme.statusTeal),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Avg Latency: ${data.avgLatencyMs.toStringAsFixed(1)} ms',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIncidentTile(RecentIncidentModel inc) {
    final color = AppTheme.severityColor(inc.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inc.ticketId,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusBadge(label: '${inc.severity} • ${inc.statusLabel}', color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inc.component.isNotEmpty ? inc.component : inc.targetName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            inc.message,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.formatDateTime(inc.time),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                'Teknisi: ${inc.technicians}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
