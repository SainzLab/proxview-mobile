import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/analytics_model.dart';
import '../viewmodels/analytics_viewmodel.dart';
import 'common_widgets.dart';

// Adaptive Theme Colors
Color get _bgCard => AppTheme.bgCard;
Color get _bgSurface => AppTheme.bgSurface;
Color get _borderSubtle => AppTheme.borderColor;
Color get _textMain => AppTheme.textMain;
Color get _textSecondary => AppTheme.textSecondary;
Color get _textMuted => AppTheme.textMuted;
Color get _textHint => AppTheme.textHint;

class SlaAnalyticsView extends StatelessWidget {
  const SlaAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final vm = context.watch<AnalyticsViewModel>();

    if (vm.isLoading && vm.analytics == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2.5),
      );
    }

    if (vm.errorMessage != null && vm.analytics == null) {
      return ErrorStateBox(
        message: vm.errorMessage!,
        onRetry: () => vm.fetchAnalytics(showLoading: true),
      );
    }

    return RefreshIndicator(
      color: AppTheme.statusTeal,
      backgroundColor: _bgCard,
      onRefresh: () => vm.fetchAnalytics(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: const [
          SlaMetricsSection(),
          SizedBox(height: 36),
        ],
      ),
    );
  }
}

/// Widget reusable untuk Analitik Kinerja SLA (Uptime, Downtime, MTTR & Availability)
class SlaMetricsSection extends StatelessWidget {
  const SlaMetricsSection({super.key});

  String _periodDescription(String period) {
    switch (period) {
      case '7d':
        return '7 Hari Terakhir';
      case '30d':
        return '30 Hari Terakhir';
      default:
        return '24 Jam Terakhir';
    }
  }

  String _severityDescription(String severity) {
    switch (severity.toUpperCase()) {
      case 'DOWN':
        return 'Level Down';
      case 'CRITICAL':
        return 'Level Critical';
      case 'WARNING':
        return 'Level Warning';
      default:
        return 'Semua Level (Warning, Critical, Down)';
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final vm = context.watch<AnalyticsViewModel>();
    final data = vm.analytics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'FILTER & PARAMETER',
          icon: Icons.tune_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.statusTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.insert_chart_outlined_rounded,
                      color: AppTheme.statusTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analitik Kinerja & Keandalan Sistem',
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_periodDescription(vm.selectedPeriod)} • ${_severityDescription(vm.selectedSeverity)}',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSegmentedFilters(vm),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (vm.isLoading && data == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2),
            ),
          )
        else if (data != null) ...[
          const SectionTitle(
            title: 'RINGKASAN METRIK',
            icon: Icons.speed_rounded,
          ),
          const SizedBox(height: 12),
          _buildFourMetricCards(data.summary),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'GRAFIK DISTRIBUSI & TREN',
            icon: Icons.stacked_bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          _buildUptimeDowntimeCard(data.chartData, vm.selectedPeriod),
          const SizedBox(height: 16),
          _buildMttrChartCard(data.chartData, vm.selectedPeriod),
          const SizedBox(height: 16),
          _buildAvailabilityChartCard(data.chartData, vm.selectedPeriod),
        ] else if (vm.errorMessage != null)
          ErrorStateBox(
            message: vm.errorMessage!,
            onRetry: () => vm.fetchAnalytics(showLoading: true),
          ),
      ],
    );
  }

  Widget _buildSegmentedFilters(AnalyticsViewModel vm) {
    final severities = [
      ('ALL', 'Semua'),
      ('DOWN', 'Down'),
      ('CRITICAL', 'Critical'),
      ('WARNING', 'Warning'),
    ];

    final periods = [
      ('24h', '24 Jam'),
      ('7d', '7 Hari'),
      ('30d', '30 Hari'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPillRow(
          items: severities,
          selectedValue: vm.selectedSeverity,
          onTap: (val) => vm.fetchAnalytics(severity: val, showLoading: false),
        ),
        const SizedBox(height: 10),
        _buildPillRow(
          items: periods,
          selectedValue: vm.selectedPeriod,
          onTap: (val) => vm.fetchAnalytics(period: val, showLoading: false),
        ),
      ],
    );
  }

  Widget _buildPillRow({
    required List<(String, String)> items,
    required String selectedValue,
    required Function(String) onTap,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          final isSelected = selectedValue == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => onTap(item.$1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.statusTeal.withValues(alpha: 0.1)
                      : _bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.statusTeal.withValues(alpha: 0.4)
                        : _borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    color: isSelected ? AppTheme.statusTeal : _textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFourMetricCards(SlaSummaryModel s) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSlaStatCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppTheme.statusTeal,
                  label: 'TOTAL UPTIME',
                  value: Formatters.formatDurationSeconds(s.totalUptimeSec),
                  subtitle: 'Durasi operasional normal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSlaStatCard(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppTheme.statusDown,
                  label: 'TOTAL DOWNTIME',
                  value: Formatters.formatDurationSeconds(s.totalDowntimeSec),
                  subtitle: 'Gangguan (${s.incidentCount} insiden)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSlaStatCard(
                  icon: Icons.restore_rounded,
                  iconColor: AppTheme.statusRecovered,
                  label: 'MTTR',
                  value: Formatters.formatDurationSeconds(s.mttrSec),
                  subtitle: 'Rata-rata waktu pemulihan',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAvailabilityStatCard(s),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlaStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            iconColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: _textMain,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: _textMuted, fontSize: 10, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStatCard(SlaSummaryModel s) {
    final availColor = s.availability >= 99.0
        ? AppTheme.statusTeal
        : (s.availability >= 95.0 ? AppTheme.statusWarning : AppTheme.statusDown);
    final clamped = (s.availability / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: availColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: availColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            availColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: availColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AVAILABILITY',
                  style: TextStyle(
                    color: availColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: s.availability.toStringAsFixed(2),
                    style: TextStyle(
                      color: availColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      color: availColor.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 4,
              backgroundColor: _bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(availColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.availability >= 99.0 ? 'Ketersediaan (target ≥99%)' : 'Di bawah target SLA',
            style: TextStyle(color: _textMuted, fontSize: 10, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUptimeDowntimeCard(List<SlaChartPointModel> points, String period) {
    final isHourly = period == '24h';
    final unitBadge = isHourly ? 'Satuan: Menit' : 'Satuan: Jam';

    int totalUpSec = 0;
    int totalDownSec = 0;
    for (final p in points) {
      totalUpSec += p.totalUptimeSec;
      totalDownSec += p.totalDowntimeSec;
    }

    final int avgUpSec = points.isNotEmpty ? (totalUpSec / points.length).round() : 0;
    final String avgUpStr = Formatters.formatDurationSeconds(avgUpSec);
    final String totalDownStr = Formatters.formatDurationSeconds(totalDownSec);

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
              Expanded(
                child: Text(
                  'Uptime & Downtime',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderSubtle),
                ),
                child: Text(
                  unitBadge,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              ChartLegendItem(color: AppTheme.statusTeal, label: 'Uptime'),
              SizedBox(width: 16),
              ChartLegendItem(color: AppTheme.statusDown, label: 'Downtime'),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data grafik Uptime & Downtime.',
                      style: TextStyle(color: _textHint, fontSize: 12),
                    ),
                  )
                : _buildUptimeBarChart(points, isHourly: isHourly),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildMetricStatBox(
                    label: 'Rata-rata Uptime',
                    value: avgUpStr,
                    color: AppTheme.statusTeal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricStatBox(
                    label: 'Total Downtime',
                    value: totalDownStr,
                    color: AppTheme.statusDown,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUptimeBarChart(List<SlaChartPointModel> points, {required bool isHourly}) {
    final double divisor = isHourly ? 60.0 : 3600.0;
    final double maxY = isHourly ? 60.0 : 24.0;
    final double interval = isHourly ? 15.0 : 6.0;

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) return null;
              final p = points[groupIndex];
              final isUp = rod.color == AppTheme.statusTeal;
              final name = isUp ? 'Uptime' : 'Downtime';
              final sec = isUp ? p.totalUptimeSec : p.totalDowntimeSec;
              final formattedDuration = Formatters.formatDurationSeconds(sec);
              return BarTooltipItem(
                rodIndex == 0 && p.label.isNotEmpty
                    ? '${p.label}\n$name: $formattedDuration'
                    : '$name: $formattedDuration',
                TextStyle(
                  color: isUp ? AppTheme.statusTeal : AppTheme.statusDown,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.35,
                ),
              );
            },
          ),
        ),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              interval: interval,
              getTitlesWidget: (val, _) {
                String text;
                if (isHourly) {
                  if (val == 0) {
                    text = '0m';
                  } else if (val >= 60) {
                    text = '1j';
                  } else {
                    text = '${val.toInt()}m';
                  }
                } else {
                  text = val == 0 ? '0j' : '${val.toInt()}j';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    text,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: _textHint, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final step = (points.length / 5).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
                    style: TextStyle(
                        color: _textHint, fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          final upVal = (p.totalUptimeSec / divisor).clamp(0.0, maxY);
          final downVal = (p.totalDowntimeSec / divisor).clamp(0.0, maxY);
          final rodWidth = points.length > 20 ? 5.0 : 8.0;
          final radius = BorderRadius.circular(4);

          return BarChartGroupData(
            x: i,
            barsSpace: 2,
            barRods: [
              BarChartRodData(
                  toY: upVal, color: AppTheme.statusTeal, width: rodWidth, borderRadius: radius),
              if (downVal > 0)
                BarChartRodData(
                    toY: downVal, color: AppTheme.statusDown, width: rodWidth, borderRadius: radius),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMttrChartCard(List<SlaChartPointModel> points, String period) {
    final isHourly = period == '24h';
    final subtitle =
        isHourly ? 'Rata-rata durasi pemulihan per jam' : 'Rata-rata durasi pemulihan per hari';

    final activePoints = points.where((p) => p.mttrSec > 0).toList();
    SlaChartPointModel? longestPoint;
    SlaChartPointModel? shortestPoint;
    int totalMttr = 0;

    if (activePoints.isNotEmpty) {
      longestPoint = activePoints.reduce((curr, next) => curr.mttrSec >= next.mttrSec ? curr : next);
      shortestPoint = activePoints.reduce((curr, next) => curr.mttrSec <= next.mttrSec ? curr : next);
      for (final p in activePoints) {
        totalMttr += p.mttrSec;
      }
    }

    final String longestLabel =
        longestPoint != null ? 'Terlama (${longestPoint.label})' : 'Terlama';
    final String longestVal =
        longestPoint != null ? Formatters.formatDurationSeconds(longestPoint.mttrSec) : '0d';

    final String shortestLabel =
        shortestPoint != null ? 'Tercepat (${shortestPoint.label})' : 'Tercepat';
    final String shortestVal =
        shortestPoint != null ? Formatters.formatDurationSeconds(shortestPoint.mttrSec) : '0d';

    final int avgSec = activePoints.isNotEmpty ? (totalMttr / activePoints.length).round() : 0;
    final String avgLabel = 'Rata-rata (${activePoints.length} periode)';
    final String avgVal = activePoints.isNotEmpty ? Formatters.formatDurationSeconds(avgSec) : '0d';

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MTTR (Mean Time To Recover)',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              ChartLegendItem(color: AppTheme.statusRecovered, label: 'Durasi MTTR'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data grafik MTTR.',
                      style: TextStyle(color: _textHint, fontSize: 12),
                    ),
                  )
                : _buildMttrBarChart(points),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 420) {
                return Row(
                  children: [
                    Expanded(
                        child: _buildMttrStatBox(
                            label: longestLabel, value: longestVal, color: AppTheme.statusDown)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMttrStatBox(
                            label: shortestLabel, value: shortestVal, color: AppTheme.statusTeal)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildMttrStatBox(
                            label: avgLabel, value: avgVal, color: AppTheme.statusRecovered)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _buildMttrStatBox(
                                label: longestLabel, value: longestVal, color: AppTheme.statusDown)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildMttrStatBox(
                                label: shortestLabel, value: shortestVal, color: AppTheme.statusTeal)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMttrStatBox(
                        label: avgLabel, value: avgVal, color: AppTheme.statusRecovered, isFullWidth: true),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  double _calculateMttrInterval(int maxSec) {
    if (maxSec <= 10) return 2.0;
    if (maxSec <= 30) return 5.0;
    if (maxSec <= 60) return 10.0;
    if (maxSec <= 120) return 20.0;
    if (maxSec <= 300) return 60.0;
    if (maxSec <= 600) return 120.0;
    if (maxSec <= 1800) return 300.0;
    if (maxSec <= 3600) return 600.0;
    if (maxSec <= 7200) return 1200.0;
    if (maxSec <= 21600) return 3600.0;
    if (maxSec <= 86400) return 7200.0;
    return (maxSec / 5).ceilToDouble();
  }

  Widget _buildMttrBarChart(List<SlaChartPointModel> points) {
    int maxMttr = 0;
    for (final p in points) {
      if (p.mttrSec > maxMttr) maxMttr = p.mttrSec;
    }
    final double interval = _calculateMttrInterval(maxMttr);
    final double maxY = maxMttr == 0
        ? (interval * 4)
        : math.max((maxMttr / interval).ceil() * interval, interval * 3);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final sec = rod.toY.toInt();
              final formatted = Formatters.formatDurationSeconds(sec);
              final dateLabel = groupIndex >= 0 && groupIndex < points.length ? points[groupIndex].label : '';

              return BarTooltipItem(
                dateLabel.isNotEmpty ? '$dateLabel\nMTTR: $formatted' : 'MTTR: $formatted',
                const TextStyle(
                  color: AppTheme.statusRecovered,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.35,
                ),
              );
            },
          ),
        ),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (val, _) {
                if (val < 0 || val > maxY + 0.1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    Formatters.formatDurationSeconds(val.toInt()),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _textHint,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final step = (points.length / 6).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
                    style: TextStyle(
                        color: _textHint, fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          final mttrVal = p.mttrSec.toDouble().clamp(0.0, maxY);
          final rodWidth = points.length > 20 ? 6.0 : (points.length > 10 ? 10.0 : 16.0);
          const radius = BorderRadius.vertical(top: Radius.circular(5));

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: mttrVal,
                color: AppTheme.statusRecovered,
                width: rodWidth,
                borderRadius: radius,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMetricStatBox({
    required String label,
    required String value,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMttrStatBox({
    required String label,
    required String value,
    required Color color,
    bool isFullWidth = false,
  }) {
    return _buildMetricStatBox(
      label: label,
      value: value,
      color: color,
      isFullWidth: isFullWidth,
    );
  }

  Widget _buildAvailabilityChartCard(List<SlaChartPointModel> points, String period) {
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
              Expanded(
                child: Text(
                  'Tren Ketersediaan (Availability %)',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              ChartLegendItem(color: AppTheme.statusTeal, label: 'Availability %'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data grafik Availability.',
                      style: TextStyle(color: _textHint, fontSize: 12),
                    ),
                  )
                : _buildAvailabilityLineChart(points),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityLineChart(List<SlaChartPointModel> points) {
    double minAvail = 100.0;
    for (final p in points) {
      minAvail = math.min(minAvail, p.availability);
    }
    final double minY = minAvail >= 99.0 ? 95.0 : (minAvail - 1.5).floorToDouble().clamp(0.0, 95.0);
    final double range = 100.0 - minY;
    final double interval = range <= 10.0 ? 2.0 : (range / 4.0).ceilToDouble();

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].availability.clamp(minY, 100.0)),
    );

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final dateLabel = (idx >= 0 && idx < points.length) ? points[idx].label : '';
                final val = spot.y.toStringAsFixed(2);

                return LineTooltipItem(
                  dateLabel.isNotEmpty ? '$dateLabel\n$val%' : '$val%',
                  const TextStyle(
                    color: AppTheme.statusTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: minY,
        maxY: 100.0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
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
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${val.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: _textHint, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final step = (points.length / 5).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
                    style: TextStyle(
                        color: _textHint, fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
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
                  AppTheme.statusTeal.withValues(alpha: 0.22),
                  AppTheme.statusTeal.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}