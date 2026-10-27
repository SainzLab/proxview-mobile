import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/network_target_model.dart';
import '../viewmodels/network_viewmodel.dart';
import 'common_widgets.dart';

class NetworkTargetsView extends StatefulWidget {
  const NetworkTargetsView({super.key});

  @override
  State<NetworkTargetsView> createState() => _NetworkTargetsViewState();
}

class _NetworkTargetsViewState extends State<NetworkTargetsView>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  static const List<String> _filters = ['ALL', 'ICMP', 'TCP'];

  @override
  void initState() {
    super.initState();
    final initialFilter = context.read<NetworkViewModel>().protocolFilter;
    final initialIndex = _filters.indexOf(initialFilter);
    _tabController = TabController(
      length: _filters.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_onTabChanged);

    // Real-time update setiap 10 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        context.read<NetworkViewModel>().fetchTargets(showLoading: false);
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final vm = context.read<NetworkViewModel>();
      final newFilter = _filters[_tabController.index];
      if (vm.protocolFilter != newFilter) {
        vm.setProtocolFilter(newFilter);
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<NetworkViewModel>().setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NetworkViewModel>();

    final filterIndex = _filters.indexOf(vm.protocolFilter);
    if (filterIndex >= 0 &&
        _tabController.index != filterIndex &&
        !_tabController.indexIsChanging) {
      _tabController.animateTo(filterIndex);
    }

    if (vm.isLoading && vm.allTargets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2.5),
      );
    }

    if (vm.errorMessage != null && vm.allTargets.isEmpty) {
      return ErrorStateBox(
        message: vm.errorMessage!,
        onRetry: () => vm.fetchTargets(showLoading: true),
      );
    }

    return Column(
      children: [
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildFilterTabs(vm),
        ),
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: AppSearchField(
            controller: _searchController,
            onChanged: (val) => vm.setSearchQuery(val),
            onClear: _clearSearch,
            hintText: 'Cari target (nama, IP, port, protokol, status)...',
            hasText: vm.searchQuery.isNotEmpty,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Colors.black,
            backgroundColor: AppTheme.statusTeal,
            onRefresh: () => vm.fetchTargets(showLoading: false),
            child: vm.targets.isEmpty
                ? EmptyStateBox(
                    icon: vm.searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.router_outlined,
                    message: vm.searchQuery.isNotEmpty
                        ? 'Tidak ada target yang cocok dengan "${vm.searchQuery}".'
                        : 'Tidak ada target monitoring jaringan.',
                    onAction: vm.searchQuery.isNotEmpty ? _clearSearch : null,
                    actionLabel: vm.searchQuery.isNotEmpty ? 'Hapus Pencarian' : null,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.targets.length,
                    itemBuilder: (context, index) =>
                        _buildTargetCard(context, vm.targets[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(NetworkViewModel vm) {
    return SegmentedTabBar(
      controller: _tabController,
      onTap: (index) {
        final newFilter = _filters[index];
        if (vm.protocolFilter != newFilter) {
          vm.setProtocolFilter(newFilter);
        }
      },
      tabs: const [
        Tab(text: 'SEMUA'),
        Tab(text: 'ICMP'),
        Tab(text: 'TCP'),
      ],
    );
  }

  Widget _buildTargetCard(BuildContext context, NetworkTargetModel target) {
    final isUp = target.isUp;
    final statusColor = isUp ? AppTheme.statusTeal : AppTheme.statusDown;
    final icon = target.protocol.toUpperCase().contains('TCP')
        ? Icons.settings_ethernet_rounded
        : Icons.network_ping_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTargetHistorySheet(context, target),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUp
                  ? AppTheme.borderSubtle
                  : AppTheme.statusDown.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 16, color: statusColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        target.protocol.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  StatusBadge(label: target.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                target.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (target.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  target.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppTheme.borderSubtle, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text(
                        target.port != null
                            ? '${target.ipAddress}:${target.port}'
                            : target.ipAddress,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      target.lastLatency,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTargetHistorySheet(BuildContext context, NetworkTargetModel target) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TargetHistoryBottomSheet(target: target),
    );
  }
}

class _TargetHistoryBottomSheet extends StatefulWidget {
  final NetworkTargetModel target;

  const _TargetHistoryBottomSheet({required this.target});

  @override
  State<_TargetHistoryBottomSheet> createState() => _TargetHistoryBottomSheetState();
}

class _TargetHistoryBottomSheetState extends State<_TargetHistoryBottomSheet> {
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NetworkViewModel>().fetchTargetHistory(widget.target.id, showLoading: true);
      }
    });

    final intervalSec = widget.target.checkInterval > 0 ? widget.target.checkInterval : 5;
    _historyTimer = Timer.periodic(Duration(seconds: intervalSec), (_) {
      if (mounted) {
        context.read<NetworkViewModel>().fetchTargetHistory(widget.target.id, showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final statusColor = target.isUp ? AppTheme.statusTeal : AppTheme.statusDown;

    return Consumer<NetworkViewModel>(
      builder: (context, vm, _) {
        final points = vm.historyFor(target.id);
        return BottomSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          target.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${target.protocol.toUpperCase()} • ${target.ipAddress}${target.port != null ? ":${target.port}" : ""}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: target.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildThresholdInfo('Batas Warning', '${target.latencyWarning} ms', AppTheme.statusWarning),
                    _buildThresholdInfo('Batas Critical', '${target.latencyCritical} ms', AppTheme.statusCritical),
                    _buildThresholdInfo('Interval Cek', '${target.checkInterval}s', Colors.white70),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'GRAFIK RIWAYAT LATENCY (MS)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (points.isNotEmpty)
                    Text(
                      '${Formatters.formatTimeSeconds(points.first.time)} - ${Formatters.formatTimeSeconds(points.last.time)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: vm.isHistoryLoading && points.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.statusTeal,
                          strokeWidth: 2,
                        ),
                      )
                    : points.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada riwayat latency.',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          )
                        : _buildLatencyChart(points),
              ),
              const SizedBox(height: 16),
              if (target.lastCheck != null)
                Center(
                  child: Text(
                    'Pengecekan terakhir: ${Formatters.formatDateTime(target.lastCheck)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThresholdInfo(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLatencyChart(List<TargetLatencyPointModel> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    double maxLatency = 0;
    for (final p in points) {
      if (p.latencyMs > maxLatency) maxLatency = p.latencyMs;
    }
    final double maxY = maxLatency == 0 ? 100.0 : (maxLatency * 1.2).ceilToDouble();
    final double gridInterval = (maxY / 4) <= 0 ? 1.0 : (maxY / 4);

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].latencyMs),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceBackground,
            tooltipBorder: const BorderSide(color: AppTheme.borderHighlight, width: 1),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final point = (idx >= 0 && idx < points.length) ? points[idx] : null;
                final timeStr = point != null ? Formatters.formatTimeSeconds(point.time) : '';
                final val = spot.y.toStringAsFixed(1);
                return LineTooltipItem(
                  '$timeStr\n$val ms',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                  children: [
                    if (point != null && point.status.isNotEmpty)
                      TextSpan(
                        text: ' • ${point.status.toUpperCase()}',
                        style: TextStyle(
                          color: point.status.toUpperCase() == 'UP'
                              ? AppTheme.statusTeal
                              : AppTheme.statusDown,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (points.length / 4).clamp(1, 20).toDouble(),
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    Formatters.formatTimeSeconds(points[idx].time),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: gridInterval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${val.toInt()} ms',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: Colors.white,
                  strokeWidth: 1.5,
                  strokeColor: AppTheme.statusTeal,
                );
              },
            ),
            shadow: Shadow(
              color: AppTheme.statusTeal.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
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