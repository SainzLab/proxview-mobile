import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/analytics_model.dart';
import '../services/pdf_export_service.dart';
import '../viewmodels/analytics_viewmodel.dart';
import 'common_widgets.dart';
import 'pdf_export_sheet.dart';

// Adaptive Theme Colors
Color get _bgCard => AppTheme.bgCard;
Color get _bgSurface => AppTheme.bgSurface;
Color get _borderSubtle => AppTheme.borderColor;
Color get _textMain => AppTheme.textMain;
Color get _textSecondary => AppTheme.textSecondary;
Color get _textMuted => AppTheme.textMuted;
Color get _textHint => AppTheme.textHint;
const Color _mtbfAccent = Color(0xFF6366F1); // Indigo accent for MTBF

class SlaAnalyticsView extends StatelessWidget {
  const SlaAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    final vm = context.watch<AnalyticsViewModel>();

    if (vm.isLoading && vm.analytics == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.statusTeal,
          strokeWidth: 2.5,
        ),
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
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: const [
          SlaMetricsSection(),
          SizedBox(height: 36),
        ],
      ),
    );
  }
}

/// Widget reusable untuk Analitik Kinerja SLA (Uptime, Downtime, MTTR, MTBF & Availability)
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
        return 'Semua Level';
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    final vm = context.watch<AnalyticsViewModel>();
    final data = vm.analytics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'FILTER & PARAMETER',
          icon: Icons.tune_rounded,
          trailing: PdfExportButton(
            initialType: PdfReportType.incidents,
            initialPeriod: vm.selectedPeriod,
            initialSeverity: vm.selectedSeverity,
            label: 'Unduh PDF',
            compact: true,
          ),
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
              ),
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
                      border: Border.all(
                        color: AppTheme.statusTeal.withValues(alpha: 0.2),
                      ),
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
              child: CircularProgressIndicator(
                color: AppTheme.statusTeal,
                strokeWidth: 2,
              ),
            ),
          )
        else if (data != null) ...[
          SectionTitle(
            title: 'RINGKASAN METRIK',
            icon: Icons.speed_rounded,
            trailing: vm.isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.statusTeal,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _buildFiveMetricCards(data.summary, vm.selectedSeverity),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'GRAFIK DISTRIBUSI',
            icon: Icons.stacked_bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          _buildUptimeDowntimeCard(
            data.chartData,
            vm.selectedPeriod,
            vm.selectedSeverity,
          ),
          const SizedBox(height: 16),
          _buildMtbfChartCard(data.chartData, vm.selectedPeriod),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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

  Widget _buildFiveMetricCards(SlaSummaryModel s, String selectedSeverity) {
    final sev = selectedSeverity.toUpperCase();
    final isCritical = sev == 'CRITICAL';
    final isWarning = sev == 'WARNING';
    final isGangguan = isCritical || isWarning;

    final IconData issueIcon = isCritical
        ? Icons.report_problem_rounded
        : (isWarning
            ? Icons.warning_amber_rounded
            : Icons.error_outline_rounded);

    final Color issueColor = isCritical
        ? AppTheme.statusCritical
        : (isWarning ? AppTheme.statusWarning : AppTheme.statusDown);

    final String issueLabel = isGangguan ? 'TOTAL GANGGUAN' : 'TOTAL DOWNTIME';

    final String issueValue = isWarning
        ? (s.totalDegradationSec > 0 ? s.degradationDuration : s.downtimeDuration)
        : (isCritical && s.totalDowntimeSec == 0 && s.totalDegradationSec > 0
            ? s.degradationDuration
            : s.downtimeDuration);

    final String issueSubtitle = isCritical
        ? 'Akumulasi waktu gangguan kritis'
        : (isWarning
            ? 'Akumulasi waktu peringatan performa'
            : (sev == 'DOWN'
                ? 'Akumulasi waktu layanan terputus'
                : 'Akumulasi waktu downtime & gangguan'));

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
                  value: s.uptimeDuration,
                  subtitle: 'Waktu sistem beroperasi normal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSlaStatCard(
                  icon: issueIcon,
                  iconColor: issueColor,
                  label: issueLabel,
                  value: issueValue,
                  subtitle: issueSubtitle,
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
                  value: s.mttrDuration,
                  subtitle: 'Rata-rata waktu pemulihan per insiden',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSlaStatCard(
                  icon: Icons.shield_outlined,
                  iconColor: _mtbfAccent,
                  label: 'MTBF',
                  value: s.mtbfDuration,
                  subtitle: 'Rata-rata waktu beroperasi antar kegagalan',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAvailabilityStatCard(s),
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
          ),
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
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
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
        : (s.availability >= 95.0
            ? AppTheme.statusWarning
            : AppTheme.statusDown);

    final clamped = (s.availability / 100.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: availColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: availColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            availColor.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                // PERBAIKAN: Dibungkus dengan Expanded
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: availColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      // PERBAIKAN: Dibungkus dengan Expanded
                      child: Text(
                        'AVAILABILITY',
                        style: TextStyle(
                          color: availColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow
                            .ellipsis, // PERBAIKAN: Tambahkan ellipsis
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: s.availability.toStringAsFixed(2),
                  style: TextStyle(
                    color: availColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: '%',
                  style: TextStyle(
                    color: availColor.withValues(alpha: 0.75),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: _bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(availColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.availability >= 99.0
                ? 'Ketersediaan memenuhi target (≥99.00%)'
                : 'Ketersediaan dibawah target (≥99.00%)',
            style: TextStyle(color: _textMuted, fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildUptimeDowntimeCard(
    List<SlaChartPointModel> points,
    String period,
    String selectedSeverity,
  ) {
    final isHourly = period == '24h';

    final sev = selectedSeverity.toUpperCase();
    final isCritical = sev == 'CRITICAL';
    final isWarning = sev == 'WARNING';
    final isGangguan = isCritical || isWarning;

    final String issueLabel = isGangguan ? 'Gangguan' : 'Downtime';
    final Color issueColor = isCritical
        ? AppTheme.statusCritical
        : (isWarning ? AppTheme.statusWarning : AppTheme.statusDown);

    final String subtitle = isHourly
        ? 'Durasi uptime dan ${issueLabel.toLowerCase()} per jam'
        : 'Durasi uptime dan ${issueLabel.toLowerCase()} per hari';

    int resolveIssueSec(SlaChartPointModel p) {
      if (isWarning) {
        return p.totalDegradationSec > 0
            ? p.totalDegradationSec
            : p.totalDowntimeSec;
      }
      if (isCritical && p.totalDowntimeSec == 0 && p.totalDegradationSec > 0) {
        return p.totalDegradationSec;
      }
      return p.totalDowntimeSec;
    }

    String resolveIssueDuration(SlaChartPointModel p) {
      if (isWarning) {
        return p.totalDegradationSec > 0
            ? p.degradationDuration
            : p.downtimeDuration;
      }
      if (isCritical && p.totalDowntimeSec == 0 && p.totalDegradationSec > 0) {
        return p.degradationDuration;
      }
      return p.downtimeDuration;
    }

    int totalUpSec = 0;
    int totalIssueSec = 0;

    for (final p in points) {
      totalUpSec += p.totalUptimeSec;
      totalIssueSec += resolveIssueSec(p);
    }

    final int avgUpSec =
        points.isNotEmpty ? (totalUpSec / points.length).round() : 0;
    final String avgUpStr = Formatters.formatDurationSeconds(avgUpSec);
    final String totalIssueStr =
        Formatters.formatDurationSeconds(totalIssueSec);

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
          Text(
            'Uptime & $issueLabel',
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
          const SizedBox(height: 14),
          Row(
            children: [
              const ChartLegendItem(color: AppTheme.statusTeal, label: 'Uptime'),
              const SizedBox(width: 16),
              ChartLegendItem(color: issueColor, label: issueLabel),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data grafik Uptime & $issueLabel.',
                      style: TextStyle(color: _textHint, fontSize: 12),
                    ),
                  )
                : _buildUptimeBarChart(
                    points,
                    isHourly: isHourly,
                    issueLabel: issueLabel,
                    issueColor: issueColor,
                    getIssueSec: resolveIssueSec,
                    getIssueDuration: resolveIssueDuration,
                  ),
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
                    label: 'Total $issueLabel',
                    value: totalIssueStr,
                    color: issueColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUptimeBarChart(
    List<SlaChartPointModel> points, {
    required bool isHourly,
    required String issueLabel,
    required Color issueColor,
    required int Function(SlaChartPointModel p) getIssueSec,
    required String Function(SlaChartPointModel p) getIssueDuration,
  }) {
    final double divisor = isHourly ? 60.0 : 3600.0;
    final double maxY = isHourly ? 60.0 : 24.0;
    final double interval = isHourly ? 15.0 : 6.0;

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) return null;
              final p = points[groupIndex];
              final isUp = rod.color == AppTheme.statusTeal;
              final name = isUp ? 'Uptime' : issueLabel;
              final formattedDuration =
                  isUp ? p.uptimeDuration : getIssueDuration(p);

              return BarTooltipItem(
                rodIndex == 0 && p.label.isNotEmpty
                    ? '${p.label}\n$name: $formattedDuration'
                    : '$name: $formattedDuration',
                TextStyle(
                  color: isUp ? AppTheme.statusTeal : issueColor,
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final step = (points.length / 5).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
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
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          final upVal = (p.totalUptimeSec / divisor).clamp(0.0, maxY);
          final issueVal = (getIssueSec(p) / divisor).clamp(0.0, maxY);
          final rodWidth = points.length > 20 ? 5.0 : 8.0;
          final radius = BorderRadius.circular(4);

          return BarChartGroupData(
            x: i,
            barsSpace: 2,
            barRods: [
              BarChartRodData(
                toY: upVal,
                color: AppTheme.statusTeal,
                width: rodWidth,
                borderRadius: radius,
              ),
              if (issueVal > 0)
                BarChartRodData(
                  toY: issueVal,
                  color: issueColor,
                  width: rodWidth,
                  borderRadius: radius,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMtbfChartCard(List<SlaChartPointModel> points, String period) {
    final isHourly = period == '24h';
    final subtitle = isHourly
        ? 'Rata-rata waktu beroperasi antar kegagalan per jam'
        : 'Rata-rata waktu beroperasi antar kegagalan per hari';

    final validPoints = points.where((p) => p.mtbfSec > 0).toList();
    SlaChartPointModel? bestPoint;
    SlaChartPointModel? lowestPoint;
    int totalMtbf = 0;

    if (validPoints.isNotEmpty) {
      bestPoint = validPoints
          .reduce((curr, next) => curr.mtbfSec >= next.mtbfSec ? curr : next);
      lowestPoint = validPoints
          .reduce((curr, next) => curr.mtbfSec <= next.mtbfSec ? curr : next);

      for (final p in validPoints) {
        totalMtbf += p.mtbfSec;
      }
    }

    final String bestLabel =
        bestPoint != null ? 'Tertinggi (${bestPoint.label})' : 'Tertinggi';
    final String bestVal = bestPoint?.mtbfDuration ?? '0d';
    final String lowestLabel =
        lowestPoint != null ? 'Terendah (${lowestPoint.label})' : 'Terendah';
    final String lowestVal = lowestPoint?.mtbfDuration ?? '0d';

    final int avgSec =
        validPoints.isNotEmpty ? (totalMtbf / validPoints.length).round() : 0;
    final String avgVal = validPoints.isNotEmpty
        ? Formatters.formatDurationSeconds(avgSec)
        : '0d';

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
          Text(
            'MTBF (Mean Time Between Failures)',
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
          const SizedBox(height: 14),
          const Row(
            children: [
              ChartLegendItem(color: _mtbfAccent, label: 'Durasi MTBF'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data grafik MTBF.',
                      style: TextStyle(color: _textHint, fontSize: 12),
                    ),
                  )
                : _buildDurationBarChart(
                    points: points,
                    getSec: (p) => p.mtbfSec,
                    getDurationStr: (p) => p.mtbfDuration,
                    metricName: 'MTBF',
                    barColor: _mtbfAccent,
                  ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 420) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricStatBox(
                        label: bestLabel,
                        value: bestVal,
                        color: AppTheme.statusTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricStatBox(
                        label: lowestLabel,
                        value: lowestVal,
                        color: AppTheme.statusWarning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricStatBox(
                        label: 'Rata-rata MTBF',
                        value: avgVal,
                        color: _mtbfAccent,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricStatBox(
                          label: bestLabel,
                          value: bestVal,
                          color: AppTheme.statusTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricStatBox(
                          label: lowestLabel,
                          value: lowestVal,
                          color: AppTheme.statusWarning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMetricStatBox(
                    label: 'Rata-rata MTBF',
                    value: avgVal,
                    color: _mtbfAccent,
                    isFullWidth: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMttrChartCard(List<SlaChartPointModel> points, String period) {
    final isHourly = period == '24h';
    final subtitle = isHourly
        ? 'Rata-rata durasi pemulihan per jam'
        : 'Rata-rata durasi pemulihan per hari';

    final activePoints = points.where((p) => p.mttrSec > 0).toList();
    SlaChartPointModel? longestPoint;
    SlaChartPointModel? shortestPoint;
    int totalMttr = 0;

    if (activePoints.isNotEmpty) {
      longestPoint = activePoints
          .reduce((curr, next) => curr.mttrSec >= next.mttrSec ? curr : next);
      shortestPoint = activePoints
          .reduce((curr, next) => curr.mttrSec <= next.mttrSec ? curr : next);

      for (final p in activePoints) {
        totalMttr += p.mttrSec;
      }
    }

    final String longestLabel =
        longestPoint != null ? 'Terlama (${longestPoint.label})' : 'Terlama';
    final String longestVal = longestPoint?.mttrDuration ?? '0d';
    final String shortestLabel = shortestPoint != null
        ? 'Tercepat (${shortestPoint.label})'
        : 'Tercepat';
    final String shortestVal = shortestPoint?.mttrDuration ?? '0d';

    final int avgSec = activePoints.isNotEmpty
        ? (totalMttr / activePoints.length).round()
        : 0;
    const String avgLabel = 'Rata-rata MTTR';
    final String avgVal = activePoints.isNotEmpty
        ? Formatters.formatDurationSeconds(avgSec)
        : '0d';

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
              ChartLegendItem(
                color: AppTheme.statusRecovered,
                label: 'Durasi MTTR',
              ),
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
                : _buildDurationBarChart(
                    points: points,
                    getSec: (p) => p.mttrSec,
                    getDurationStr: (p) => p.mttrDuration,
                    metricName: 'MTTR',
                    barColor: AppTheme.statusRecovered,
                  ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 420) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricStatBox(
                        label: longestLabel,
                        value: longestVal,
                        color: AppTheme.statusDown,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricStatBox(
                        label: shortestLabel,
                        value: shortestVal,
                        color: AppTheme.statusTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricStatBox(
                        label: avgLabel,
                        value: avgVal,
                        color: AppTheme.statusRecovered,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricStatBox(
                            label: longestLabel,
                            value: longestVal,
                            color: AppTheme.statusDown,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricStatBox(
                            label: shortestLabel,
                            value: shortestVal,
                            color: AppTheme.statusTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildMetricStatBox(
                      label: avgLabel,
                      value: avgVal,
                      color: AppTheme.statusRecovered,
                      isFullWidth: true,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  double _calculateDurationInterval(int maxSec) {
    if (maxSec <= 10) return 2.0;
    if (maxSec <= 30) return 5.0;
    if (maxSec <= 60) return 10.0;
    if (maxSec <= 120) return 20.0;
    if (maxSec <= 300) return 60.0;
    if (maxSec <= 600) return 120.0;
    if (maxSec <= 1800) return 300.0;
    if (maxSec <= 3600) return 900.0;
    if (maxSec <= 7200) return 1800.0;
    if (maxSec <= 21600) return 3600.0;
    if (maxSec <= 86400) return 21600.0;
    return (maxSec / 4).ceilToDouble();
  }

  Widget _buildDurationBarChart({
    required List<SlaChartPointModel> points,
    required int Function(SlaChartPointModel p) getSec,
    required String Function(SlaChartPointModel p) getDurationStr,
    required String metricName,
    required Color barColor,
  }) {
    int maxSec = 0;
    for (final p in points) {
      final sec = getSec(p);
      if (sec > maxSec) maxSec = sec;
    }

    final double interval = _calculateDurationInterval(maxSec);
    final double maxY = maxSec == 0
        ? (interval * 4)
        : math.max((maxSec / interval).ceil() * interval, interval * 3);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _bgCard,
            tooltipBorder: BorderSide(color: _borderSubtle, width: 1),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) return null;
              final p = points[groupIndex];
              final formatted = getDurationStr(p);
              final dateLabel = p.label;

              return BarTooltipItem(
                dateLabel.isNotEmpty
                    ? '$dateLabel\n$metricName: $formatted'
                    : '$metricName: $formatted',
                TextStyle(
                  color: barColor,
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
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
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final step = (points.length / 6).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
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
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          final val = getSec(p).toDouble().clamp(0.0, maxY);
          final rodWidth =
              points.length > 20 ? 6.0 : (points.length > 10 ? 10.0 : 16.0);
          const radius = BorderRadius.vertical(top: Radius.circular(5));

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: barColor,
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

  Widget _buildAvailabilityChartCard(
    List<SlaChartPointModel> points,
    String period,
  ) {
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
              ChartLegendItem(
                color: AppTheme.statusTeal,
                label: 'Availability %',
              ),
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

    final double minY = minAvail >= 99.0
        ? 95.0
        : (minAvail - 1.5).floorToDouble().clamp(0.0, 95.0);

    final double range = 100.0 - minY;
    final double interval =
        range <= 10.0 ? 2.0 : (range / 4.0).ceilToDouble();

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
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final dateLabel =
                    (idx >= 0 && idx < points.length) ? points[idx].label : '';
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
              interval: 1,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                final step = (points.length / 5).ceil().clamp(1, 10);
                if (idx % step != 0 && idx != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[idx].label,
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