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

  static const Color _emeraldColor = Color(0xFF10B981);
  static const Color _roseColor = Color(0xFFF43F5E);
  static const Color _cardBgColor = Color(0xFF0D1117);

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

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchTargets(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Filter Protocol TabBar (disesuaikan persis seperti logs_view.dart)
          _buildFilterTabs(vm),
          const SizedBox(height: 12),

          // Kolom Input Pencarian Target
          TextField(
            controller: _searchController,
            onChanged: (val) => vm.setSearchQuery(val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            cursorColor: AppTheme.statusTeal,
            decoration: InputDecoration(
              hintText: 'Cari target (nama, IP, port, protokol, status)...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: vm.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: _clearSearch,
                      tooltip: 'Hapus pencarian',
                    )
                  : null,
              filled: true,
              fillColor: _cardBgColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.statusTeal, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (vm.targets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      vm.searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.router_outlined,
                      size: 64,
                      color: Colors.white12,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vm.searchQuery.isNotEmpty
                          ? 'Tidak ada target yang cocok dengan "${vm.searchQuery}".'
                          : 'Tidak ada target monitoring.',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    if (vm.searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close, size: 16, color: AppTheme.statusTeal),
                        label: const Text(
                          'Hapus Pencarian',
                          style: TextStyle(color: AppTheme.statusTeal, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.statusTeal.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppTheme.statusTeal.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...vm.targets.map((target) => _buildTargetCard(context, target)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  int _countFor(NetworkViewModel vm, String filter) {
    var list = vm.allTargets;
    if (filter != 'ALL') {
      list = list.where((t) => t.protocol.toUpperCase().contains(filter)).toList();
    }
    if (vm.searchQuery.trim().isEmpty) return list.length;
    final q = vm.searchQuery.trim().toLowerCase();
    return list.where((t) {
      final portStr = t.port != null ? ':${t.port}' : '';
      return t.name.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.ipAddress.toLowerCase().contains(q) ||
          portStr.contains(q) ||
          t.protocol.toLowerCase().contains(q) ||
          t.status.toLowerCase().contains(q);
    }).length;
  }

  Widget _buildFilterTabs(NetworkViewModel vm) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppTheme.statusTeal.withValues(alpha: 0.15),
          border: Border.all(
            color: AppTheme.statusTeal.withValues(alpha: 0.5),
          ),
        ),
        labelColor: AppTheme.statusTeal,
        unselectedLabelColor: Colors.white54,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
        onTap: (index) {
          final newFilter = _filters[index];
          if (vm.protocolFilter != newFilter) {
            vm.setProtocolFilter(newFilter);
          }
        },
        tabs: [
          Tab(text: 'SEMUA (${_countFor(vm, 'ALL')})'),
          Tab(text: 'ICMP (${_countFor(vm, 'ICMP')})'),
          Tab(text: 'TCP (${_countFor(vm, 'TCP')})'),
        ],
      ),
    );
  }

  Widget _buildTargetCard(BuildContext context, NetworkTargetModel target) {
    final isUp = target.isUp;
    final statusColor = isUp ? _emeraldColor : _roseColor;
    final icon = target.protocol.toUpperCase().contains('TCP')
        ? Icons.settings_ethernet_rounded
        : Icons.network_ping_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTargetHistorySheet(context, target),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderSubtle),
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
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16, color: statusColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        target.protocol.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
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
                  fontSize: 17,
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
                child: Divider(color: Colors.white10, height: 1),
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
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      target.lastLatency,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
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

  static const Color _emeraldColor = Color(0xFF10B981);
  static const Color _roseColor = Color(0xFFF43F5E);
  static const Color _cardBgColor = Color(0xFF0D1117);

  @override
  void initState() {
    super.initState();
    // Fetch awal data riwayat latency setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NetworkViewModel>().fetchTargetHistory(widget.target.id, showLoading: true);
      }
    });

    // Polling realtime update riwayat latency selama bottom sheet dibuka
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
    final statusColor = target.isUp ? _emeraldColor : _roseColor;

    return Consumer<NetworkViewModel>(
      builder: (context, vm, _) {
        final points = vm.historyFor(target.id);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _cardBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                            fontSize: 13,
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildThresholdInfo('Warning', '${target.latencyWarning} ms', AppTheme.statusWarning),
                    _buildThresholdInfo('Critical', '${target.latencyCritical} ms', AppTheme.statusCritical),
                    _buildThresholdInfo('Interval', '${target.checkInterval}s', Colors.white54),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'RIWAYAT LATENCY',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
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
                              style: TextStyle(color: Colors.white38),
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
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
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

    // 1. Cari nilai latency tertinggi untuk mengatur batas atas grafik (maxY)
    double maxLatency = 0;
    for (final p in points) {
      if (p.latencyMs > maxLatency) maxLatency = p.latencyMs;
    }
    // Tambahkan ruang di atas grafik sebesar +20% agar spike tidak mentok ke atap
    final double maxY = maxLatency == 0 ? 100.0 : (maxLatency * 1.2).ceilToDouble();
    // Atur interval grid secara dinamis (dibagi 4-5 baris)
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
            getTooltipColor: (touchedSpot) => const Color(0xFF161B22),
            tooltipBorder: const BorderSide(color: Colors.white24, width: 1),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    height: 1.3,
                  ),
                  children: [
                    if (point != null && point.status.isNotEmpty)
                      TextSpan(
                        text: ' • ${point.status}',
                        style: TextStyle(
                          color: point.status.toUpperCase() == 'UP'
                              ? _emeraldColor
                              : _roseColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // Sumbu Y: Menampilkan angka murni (0, 10, 20, 30...)
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: gridInterval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  val.toInt().toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white38, 
                    fontSize: 10, 
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
            // Titik dot lingkaran pada tiap titik data sesuai referensi gambar
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
            // Shadow glowing lembut pada garis
            shadow: Shadow(
              color: AppTheme.statusTeal.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            // Gradient fill di bawah kurva grafik
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.statusTeal.withValues(alpha: 0.22),
                  AppTheme.statusTeal.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}