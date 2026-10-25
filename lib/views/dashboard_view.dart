import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/dashboard_model.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'common_widgets.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback? onOpenIncidentsTab;

  const DashboardView({super.key, this.onOpenIncidentsTab});

  static const Color _cardBgColor = Color(0xFF0D1117);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();

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
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const SectionTitle(
            title: 'PROXMOX CLUSTER HEALTH',
            icon: Icons.dns_rounded,
          ),
          const SizedBox(height: 12),
          _buildProxmoxOverviewCard(context, vm, summary.proxmox),
          const SizedBox(height: 24),

          const SectionTitle(
            title: 'NETWORK TARGETS (ICMP & TCP)',
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
                ? InkWell(
                    onTap: onOpenIncidentsTab,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'LIHAT SEMUA',
                        style: TextStyle(
                          color: AppTheme.statusTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (summary.recentIncidents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: _cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppTheme.statusTeal, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Tidak ada insiden terbaru.\nSeluruh sistem beroperasi normal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                  ],
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
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  'Online Nodes', 
                  '${pve.onlineNodes}/${pve.totalNodes}', 
                  Icons.dns_rounded, 
                  AppTheme.statusTeal
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                child: _buildMiniStat(
                  'Running Guest', 
                  '${pve.runningVms}/${pve.totalVms}', 
                  Icons.computer_rounded, 
                  Colors.white
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Matrix Cluster',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
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
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tf.toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white54,
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
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _buildRrdChart(pve.chart),
          ),
          const SizedBox(height: 16),
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

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
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
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final val = spot.y.toStringAsFixed(1);
                return LineTooltipItem(
                  '$val%',
                  TextStyle(
                    color: spot.bar.color ?? Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
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
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${val.toInt()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                ),
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
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    chart.labels[idx],
                    style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w500),
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
              color: Colors.white,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.0)],
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
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.statusTeal.withValues(alpha: 0.15), AppTheme.statusTeal.withValues(alpha: 0.0)],
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
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDown ? AppTheme.statusDown.withValues(alpha: 0.4) : AppTheme.borderSubtle,
        ),
        boxShadow: hasDown
            ? [BoxShadow(color: AppTheme.statusDown.withValues(alpha: 0.1), blurRadius: 10)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Custom Badge Tanpa Titik dan Teks UP/DOWN
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Avg Latency: ${data.avgLatencyMs.toStringAsFixed(1)} ms',
            style: const TextStyle(
              color: Colors.white54,
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
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Custom Badge Tanpa Titik untuk Insiden
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${inc.severity.toUpperCase()} • ${inc.statusLabel.toUpperCase()}',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Text(
            inc.component.isNotEmpty ? inc.component : inc.targetName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            inc.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDateTime(inc.time),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    inc.technicians.isNotEmpty ? inc.technicians : 'N/A',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label, 
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)
        ),
      ],
    );
  }
}