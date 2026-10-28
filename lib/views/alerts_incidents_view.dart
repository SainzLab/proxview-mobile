import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/alert_incident_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'common_widgets.dart';

class AlertsIncidentsView extends StatefulWidget {
  const AlertsIncidentsView({super.key});

  @override
  State<AlertsIncidentsView> createState() => _AlertsIncidentsViewState();
}

class _AlertsIncidentsViewState extends State<AlertsIncidentsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Semua Status';
  final Map<String, bool> _expandedMonitoringCards = {};

  // Adaptive theme colors
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _bgSurface => AppTheme.bgSurface;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;
  static Color get _textHint => AppTheme.textHint;

  bool _isCardExpanded(String cardKey, {required bool defaultExpanded}) {
    return _expandedMonitoringCards[cardKey] ?? defaultExpanded;
  }

  void _toggleCardExpanded(String cardKey, {required bool defaultExpanded}) {
    setState(() {
      final current = _isCardExpanded(
        cardKey,
        defaultExpanded: defaultExpanded,
      );
      _expandedMonitoringCards[cardKey] = !current;
    });
  }

  final List<String> _filterOptions = [
    'Semua Status',
    'DOWN',
    'CRITICAL',
    'WARNING',
    'Dalam Penanganan',
    'Selesai',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedFilter = 'Semua Status';
    });
  }

  Future<void> _handleJoin(
    BuildContext context,
    int alertId, {
    required String targetLabel,
  }) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context,
      title: 'Tangani Insiden?',
      message:
          'Anda akan tercatat sebagai teknisi yang menangani gangguan pada "$targetLabel". Lanjutkan?',
      confirmLabel: 'YA, TANGANI',
      accentColor: AppTheme.statusRecovered,
      icon: Icons.handyman_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final vm = context.read<AlertIncidentViewModel>();
    final res = await vm.joinAlert(alertId);
    if (context.mounted) {
      AppFeedback.showSnackBar(
        context,
        message: res.message,
        isError: !res.success,
      );
    }
  }

  Future<void> _handleResolve(
    BuildContext context,
    int alertId, {
    required String targetLabel,
  }) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context,
      title: 'Selesaikan Insiden?',
      message:
          'Pastikan layanan "$targetLabel" telah pulih dan berjalan normal sebelum menutup tiket insiden ini.',
      confirmLabel: 'SELESAIKAN',
      accentColor: AppTheme.statusTeal,
      icon: Icons.check_circle_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final vm = context.read<AlertIncidentViewModel>();
    final res = await vm.resolveAlert(alertId);
    if (context.mounted) {
      AppFeedback.showSnackBar(
        context,
        message: res.message,
        isError: !res.success,
      );
    }
  }

  List<AlertModel> _filterAlerts(List<AlertModel> source) {
    return source.where((a) {
      final matchesSearch = _searchQuery.isEmpty ||
          a.targetName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.message.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesFilter = true;
      if (_selectedFilter != 'Semua Status') {
        if (_selectedFilter == 'Dalam Penanganan') {
          matchesFilter = a.isBeingHandled;
        } else if (_selectedFilter == 'Selesai') {
          matchesFilter = a.isResolved;
        } else {
          final effSev = (a.originalSeverity.isNotEmpty &&
                  a.severity.toUpperCase() == 'RECOVERED')
              ? a.originalSeverity.toUpperCase()
              : a.severity.toUpperCase();
          matchesFilter = effSev == _selectedFilter.toUpperCase();
        }
      }
      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<IncidentTicketModel> _filterIncidents(List<IncidentTicketModel> source) {
    return source.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.target.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.ticketCode.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesFilter = true;
      if (_selectedFilter != 'Semua Status') {
        if (_selectedFilter == 'Dalam Penanganan') {
          matchesFilter = t.status.toLowerCase().contains('penanganan');
        } else if (_selectedFilter == 'Selesai') {
          matchesFilter = t.isResolved || t.status.toLowerCase().contains('selesai');
        } else {
          final effSev = (t.originalSeverity.isNotEmpty &&
                  t.severity.toUpperCase() == 'RECOVERED')
              ? t.originalSeverity.toUpperCase()
              : t.severity.toUpperCase();
          matchesFilter = effSev == _selectedFilter.toUpperCase();
        }
      }
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final vm = context.watch<AlertIncidentViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final currentUserName = authVm.currentUser?.name;
    final isKepalaBidang = authVm.isKepalaBidang;
    final unhandledCount =
        vm.activeAlerts.where((a) => !a.isBeingHandled).length;

    final filteredActive = _filterAlerts(vm.activeAlerts);
    final filteredIncidents = _filterIncidents(vm.incidents);
    final filteredHistory = _filterAlerts(vm.historyAlerts);

    return DefaultTabController(
      key: ValueKey(isKepalaBidang),
      length: isKepalaBidang ? 2 : 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                color: _bgSurface,
                child: Column(
                  children: [
                    _buildIncidentStatsChart(
                      vm.incidentStats,
                      isKepalaBidang: isKepalaBidang,
                      unhandledCount: unhandledCount,
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SegmentedTabBar(
                        tabs: isKepalaBidang
                            ? [
                                Tab(text: 'AKTIF (${vm.activeAlerts.length})'),
                                Tab(text: 'RIWAYAT (${vm.historyAlerts.length})'),
                              ]
                            : [
                                Tab(text: 'AKTIF (${vm.activeAlerts.length})'),
                                Tab(text: 'TIKET (${vm.incidents.length})'),
                                Tab(text: 'RIWAYAT (${vm.historyAlerts.length})'),
                              ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: AppSearchField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              onClear: _clearSearch,
                              hintText: 'Cari tiket, target, pesan...',
                              hasText: _searchQuery.isNotEmpty,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  dropdownColor: _bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  icon: Icon(
                                    Icons.filter_list_rounded,
                                    color: _textHint,
                                    size: 18,
                                  ),
                                  isExpanded: true,
                                  style: TextStyle(
                                    color: _textMain,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: _filterOptions.map((String option) {
                                    final isSel = _selectedFilter == option;
                                    return DropdownMenuItem<String>(
                                      value: option,
                                      child: Row(
                                        children: [
                                          if (isSel)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: AppTheme.statusTeal,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              option,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isSel
                                                    ? AppTheme.statusTeal
                                                    : _textSecondary,
                                                fontWeight: isSel
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedFilter = newValue;
                                      });
                                    }
                                  },
                                ),
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
          ];
        },
        body: Container(
          color: _bgSurface,
          child: vm.isLoading && vm.activeAlerts.isEmpty && vm.incidents.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2.5),
                )
              : vm.errorMessage != null && vm.activeAlerts.isEmpty && vm.incidents.isEmpty
                  ? ErrorStateBox(
                      message: vm.errorMessage!,
                      onRetry: () => vm.fetchAll(showLoading: true),
                    )
                  : TabBarView(
                      children: [
                        _buildAlertsList(
                          context,
                          vm,
                          filteredActive,
                          currentUserName: currentUserName,
                          isKepalaBidang: isKepalaBidang,
                          emptyLabel: 'Tidak ada gangguan aktif saat ini.',
                          isActiveTab: true,
                          onLoadMore: () => vm.loadMoreActiveAlerts(),
                        ),
                        if (!isKepalaBidang)
                          _buildIncidentsList(
                            context,
                            vm,
                            filteredIncidents,
                            currentUserName,
                            isKepalaBidang: isKepalaBidang,
                            onLoadMore: () => vm.loadMoreIncidents(),
                          ),
                        _buildAlertsList(
                          context,
                          vm,
                          filteredHistory,
                          currentUserName: currentUserName,
                          isKepalaBidang: isKepalaBidang,
                          emptyLabel: 'Belum ada riwayat gangguan selesai.',
                          isActiveTab: false,
                          onLoadMore: () => vm.loadMoreHistoryAlerts(),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildIncidentStatsChart(
    IncidentStatsModel stats, {
    required bool isKepalaBidang,
    required int unhandledCount,
  }) {
    // Tampilkan akumulasi seluruh total (frontend) untuk DOWN, CRITICAL, WARNING
    final displayDown = stats.totalDown;
    final displayCritical = stats.totalCritical;
    final displayWarning = stats.totalWarning;
    final int severityTotal = displayDown + displayCritical + displayWarning;

    final double resolutionRate = stats.totalTickets > 0
        ? (stats.resolved / stats.totalTickets * 100.0)
        : 100.0;

    final items = [
      (
        label: 'DOWN',
        filterKey: 'DOWN',
        count: displayDown,
        color: AppTheme.statusDown,
      ),
      (
        label: 'CRITICAL',
        filterKey: 'CRITICAL',
        count: displayCritical,
        color: AppTheme.statusCritical,
      ),
      (
        label: 'WARNING',
        filterKey: 'WARNING',
        count: displayWarning,
        color: AppTheme.statusWarning,
      ),
      (
        label: 'PROGRES',
        filterKey: 'Dalam Penanganan',
        count: stats.progress,
        color: AppTheme.statusRecovered,
      ),
      (
        label: 'SELESAI',
        filterKey: 'Selesai',
        count: stats.resolved,
        color: AppTheme.statusTeal,
      ),
    ];

    return Container(
      color: _bgSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
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
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.statusTeal,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RINGKASAN STATUS INSIDEN',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildSummaryPill(
                      label: 'Aktif',
                      value: stats.totalActive,
                      color: stats.totalActive > 0
                          ? AppTheme.statusCritical
                          : AppTheme.statusTeal,
                    ),
                    const SizedBox(width: 6),
                    _buildSummaryPill(
                      label: 'Total',
                      value: stats.totalTickets,
                      color: _textSecondary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stacked Distribution Chart Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: severityTotal <= 0
                    ? Container(color: _bgSurface)
                    : Row(
                        children: [
                          (count: displayDown, color: AppTheme.statusDown),
                          (count: displayCritical, color: AppTheme.statusCritical),
                          (count: displayWarning, color: AppTheme.statusWarning),
                        ]
                            .where((item) => item.count > 0)
                            .map((item) {
                          return Expanded(
                            flex: item.count,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              color: item.color,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // 5 Kolom Stats Bar (Tanpa Persen & Ikon)
            Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = _selectedFilter == item.filterKey;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 3,
                      right: index == items.length - 1 ? 0 : 3,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _selectedFilter = isSelected
                              ? 'Semua Status'
                              : item.filterKey;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? item.color.withValues(alpha: 0.12)
                              : _bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? item.color.withValues(alpha: 0.5)
                                : _borderSubtle,
                            width: isSelected ? 1.2 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: item.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${item.count}',
                                style: TextStyle(
                                  color: _textMain,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (isKepalaBidang) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: _borderSubtle, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rasio Selesai: ${resolutionRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.statusTeal,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final hasFilter = _searchQuery.isNotEmpty || _selectedFilter != 'Semua Status';
    return EmptyStateBox(
      icon: hasFilter ? Icons.search_off_rounded : Icons.verified_rounded,
      message: hasFilter
          ? 'Tidak ada data yang cocok dengan pencarian atau filter aktif.'
          : message,
      onAction: hasFilter ? _resetFilters : null,
      actionLabel: hasFilter ? 'Reset Filter' : null,
    );
  }

  Widget _buildAlertsList(
    BuildContext context,
    AlertIncidentViewModel vm,
    List<AlertModel> list, {
    required String? currentUserName,
    required bool isKepalaBidang,
    required String emptyLabel,
    required bool isActiveTab,
    VoidCallback? onLoadMore,
  }) {
    return RefreshIndicator(
      color: AppTheme.statusTeal,
      backgroundColor: _bgCard,
      onRefresh: () => vm.fetchAll(showLoading: false),
      child: list.isEmpty
          ? _buildEmptyState(emptyLabel)
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!vm.isLoadingMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
                  onLoadMore?.call();
                }
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                itemCount: list.length + (vm.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == list.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2),
                      ),
                    );
                  }
                  return _buildAlertCard(
                    context,
                    vm,
                    list[index],
                    currentUserName: currentUserName,
                    isKepalaBidang: isKepalaBidang,
                    isActiveTab: isActiveTab,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    AlertIncidentViewModel vm,
    AlertModel alert, {
    required String? currentUserName,
    required bool isKepalaBidang,
    required bool isActiveTab,
  }) {
    if (isKepalaBidang) {
      final year = DateTime.tryParse(alert.createdAt)?.year ?? DateTime.now().year;
      final ticketCode =
          '#INC-$year-${alert.id.toString().padLeft(4, '0')}';
      final displaySeverity =
          alert.originalSeverity.isNotEmpty &&
                  alert.severity.toUpperCase() == 'RECOVERED'
              ? alert.originalSeverity
              : alert.severity;
      return _buildKabidMonitoringCard(
        cardKey: 'alert_${alert.id}_${isActiveTab ? "act" : "hist"}',
        ticketCode: ticketCode,
        timestamp: alert.createdAt,
        title: alert.message.isNotEmpty ? alert.message : alert.targetName,
        targetLabel: '${alert.targetType}\n${alert.targetName}',
        badgeSeverity: displaySeverity,
        currentSeverity: alert.severity,
        isResolved: alert.isResolved,
        isBeingHandled: alert.isBeingHandled,
        technicians: alert.technicians,
        downtimeDuration: null,
        handlingDuration: null,
        defaultExpanded: isActiveTab,
      );
    }

    final color = AppTheme.severityColor(alert.severity);
    final isCall = alert.isEmergencyCall;

    final bool hasJoined = currentUserName != null &&
        alert.technicians != null &&
        alert.technicians!.contains(currentUserName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveTab ? color.withValues(alpha: 0.35) : _borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: isActiveTab
                ? color.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.targetType}\n${alert.actionType.toUpperCase()}',
                      style: TextStyle(
                        color: isCall ? AppTheme.statusDown : _textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.targetName,
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                label: alert.severity,
                color: color,
                showDot: isActiveTab,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.message,
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: _borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: _textHint),
                  const SizedBox(width: 6),
                  Text(
                    Formatters.formatDateTime(alert.createdAt),
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: _textHint),
                  const SizedBox(width: 6),
                  Text(
                    alert.isBeingHandled ? (alert.technicians ?? '-') : 'Belum Ditangani',
                    style: TextStyle(
                      color: alert.isBeingHandled ? AppTheme.statusTeal : AppTheme.statusWarning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isActiveTab && !isKepalaBidang) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (vm.isSubmittingAction || hasJoined)
                        ? null
                        : () => _handleJoin(
                              context,
                              alert.id,
                              targetLabel: alert.targetName,
                            ),
                    icon: Icon(
                      hasJoined ? Icons.how_to_reg_rounded : Icons.handyman_rounded,
                      size: 16,
                    ),
                    label: Text(
                      hasJoined ? 'SUDAH JOIN' : 'TANGANI',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: _borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!alert.canResolve || vm.isSubmittingAction)
                        ? null
                        : () => _handleResolve(
                              context,
                              alert.id,
                              targetLabel: alert.targetName,
                            ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text(
                      'SELESAIKAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      disabledBackgroundColor: _bgSurface,
                      disabledForegroundColor: _textHint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncidentsList(
    BuildContext context,
    AlertIncidentViewModel vm,
    List<IncidentTicketModel> incidents,
    String? currentUserName, {
    required bool isKepalaBidang,
    VoidCallback? onLoadMore,
  }) {
    return RefreshIndicator(
      color: AppTheme.statusTeal,
      backgroundColor: _bgCard,
      onRefresh: () => vm.fetchAll(showLoading: false),
      child: incidents.isEmpty
          ? _buildEmptyState('Belum ada tiket insiden.')
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!vm.isLoadingMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
                  onLoadMore?.call();
                }
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                itemCount: incidents.length + (vm.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == incidents.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.statusTeal, strokeWidth: 2),
                      ),
                    );
                  }

                  final ticket = incidents[index];
                  if (isKepalaBidang) {
                    final displaySeverity =
                        ticket.originalSeverity.isNotEmpty &&
                                ticket.severity.toUpperCase() == 'RECOVERED'
                            ? ticket.originalSeverity
                            : ticket.severity;
                    final hasTech = ticket.technicians != null &&
                        ticket.technicians!.trim().isNotEmpty &&
                        ticket.technicians!.trim() != '-';
                    return _buildKabidMonitoringCard(
                      cardKey: 'ticket_${ticket.dbId}_${ticket.ticketCode}',
                      ticketCode: ticket.ticketCode,
                      timestamp: ticket.time,
                      title: ticket.title.isNotEmpty ? ticket.title : ticket.target,
                      targetLabel: ticket.target,
                      badgeSeverity: displaySeverity,
                      currentSeverity: ticket.severity,
                      isResolved: ticket.isResolved,
                      isBeingHandled: hasTech,
                      technicians: ticket.technicians,
                      downtimeDuration: ticket.downtimeDuration,
                      handlingDuration: ticket.handlingDuration,
                      defaultExpanded: !ticket.isResolved,
                    );
                  }

                  final color = AppTheme.severityColor(ticket.severity);
                  final bool hasJoined = currentUserName != null &&
                      ticket.technicians != null &&
                      ticket.technicians!.contains(currentUserName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !ticket.isResolved
                            ? color.withValues(alpha: 0.35)
                            : _borderSubtle,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: !ticket.isResolved
                              ? color.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.confirmation_number_outlined,
                                    size: 15,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      ticket.ticketCode,
                                      style: TextStyle(
                                        color: _textMain,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusBadge(
                              label: ticket.status,
                              color: color,
                              showDot: !ticket.isResolved,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ticket.target,
                          style: TextStyle(
                            color: _textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.title,
                          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: _borderSubtle, height: 1),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _buildChipInfo(Icons.timer_outlined, 'Downtime: ${ticket.downtimeDuration}'),
                            _buildChipInfo(Icons.engineering_outlined, 'Penanganan: ${ticket.handlingDuration}'),
                            _buildChipInfo(Icons.person_outline_rounded, 'Teknisi: ${ticket.technicians ?? "-"}'),
                          ],
                        ),
                        if (!ticket.isResolved && !isKepalaBidang) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (vm.isSubmittingAction || hasJoined)
                                      ? null
                                      : () => _handleJoin(
                                            context,
                                            ticket.dbId,
                                            targetLabel: '${ticket.ticketCode} (${ticket.target})',
                                          ),
                                  icon: Icon(
                                    hasJoined ? Icons.how_to_reg_rounded : Icons.handyman_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    hasJoined ? 'SUDAH JOIN' : 'TANGANI',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _textSecondary,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    side: BorderSide(color: _borderSubtle),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (!ticket.canResolve || vm.isSubmittingAction)
                                      ? null
                                      : () => _handleResolve(
                                            context,
                                            ticket.dbId,
                                            targetLabel: '${ticket.ticketCode} (${ticket.target})',
                                          ),
                                  icon: const Icon(Icons.warehouse, size: 16),
                                  label: const Text(
                                    'SELESAIKAN',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.statusTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    disabledBackgroundColor: _bgSurface,
                                    disabledForegroundColor: _textHint,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildKabidMonitoringCard({
    required String cardKey,
    required String ticketCode,
    required String timestamp,
    required String title,
    required String targetLabel,
    required String badgeSeverity,
    required String currentSeverity,
    required bool isResolved,
    required bool isBeingHandled,
    required String? technicians,
    required String? downtimeDuration,
    required String? handlingDuration,
    required bool defaultExpanded,
  }) {
    final isExpanded = _isCardExpanded(
      cardKey,
      defaultExpanded: defaultExpanded,
    );
    final sevColor = AppTheme.severityColor(badgeSeverity);
    final isProxmox = targetLabel.toUpperCase().contains('PROXMOX');

    // Stage 1: Terdeteksi (belum ditangani), Stage 2: Perbaikan, Stage 3: Terkonfirmasi (Selesai)
    final int stage = isResolved ? 3 : (isBeingHandled ? 2 : 1);
    final bool isRecoveredWaitingConfirm =
        !isResolved && currentSeverity.toUpperCase() == 'RECOVERED';

    late final Color statusColor;
    late final IconData statusIcon;
    late final String statusTitle;
    late final String statusSubtitle;
    late final String statusBadgeText;

    final techName = (technicians != null &&
            technicians.trim().isNotEmpty &&
            technicians.trim() != '-')
        ? technicians.trim()
        : 'Teknisi';

    if (stage == 1) {
      statusColor = AppTheme.statusDown;
      statusIcon = Icons.notifications_active_outlined;
      statusTitle = 'Menunggu Penanganan';
      statusSubtitle = 'Sistem sedang menunggu respons dari teknisi.';
      statusBadgeText = 'TERDETEKSI';
    } else if (stage == 2) {
      statusColor = isRecoveredWaitingConfirm
          ? AppTheme.statusTeal
          : AppTheme.statusRecovered;
      statusIcon = isRecoveredWaitingConfirm
          ? Icons.task_alt_rounded
          : Icons.build_outlined;
      statusTitle = isRecoveredWaitingConfirm
          ? 'Layanan Pulih • Menunggu Konfirmasi'
          : 'Sedang Dalam Perbaikan';
      final durPart =
          (handlingDuration != null &&
                  handlingDuration.isNotEmpty &&
                  handlingDuration != '-')
              ? ' • Durasi: $handlingDuration'
              : '';
      statusSubtitle = 'Ditangani oleh $techName$durPart.';
      statusBadgeText = isRecoveredWaitingConfirm ? 'PULIH' : 'PERBAIKAN';
    } else {
      statusColor = AppTheme.statusTeal;
      statusIcon = Icons.verified_outlined;
      statusTitle = 'Penanganan Terkonfirmasi';
      final downPart =
          (downtimeDuration != null &&
                  downtimeDuration.isNotEmpty &&
                  downtimeDuration != '-')
              ? ' • Total Downtime: $downtimeDuration'
              : '';
      statusSubtitle = 'Diselesaikan oleh $techName$downPart.';
      statusBadgeText = 'TERKONFIRMASI';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !isResolved
              ? sevColor.withValues(alpha: 0.35)
              : _borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: !isResolved
                ? sevColor.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _toggleCardExpanded(
            cardKey,
            defaultExpanded: defaultExpanded,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: sevColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$ticketCode \n${Formatters.formatDateTime(timestamp)}',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: TextStyle(
                                color: _textMain,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isProxmox
                                          ? Icons.dns_outlined
                                          : Icons.router_outlined,
                                      size: 14,
                                      color: _textHint,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        targetLabel,
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                StatusBadge(
                                  label: badgeSeverity,
                                  color: sevColor,
                                  showDot: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Body: Laporan Pemantauan (3-Step Stepper + Info Box)
              if (isExpanded) ...[
                Divider(color: _borderSubtle, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'LAPORAN PEMANTAUAN',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildMonitoringStepper(
                        stage: stage,
                        isRecoveredWaitingConfirm: isRecoveredWaitingConfirm,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusTitle,
                                    style: TextStyle(
                                      color: _textMain,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    statusSubtitle,
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                statusBadgeText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringStepper({
    required int stage,
    required bool isRecoveredWaitingConfirm,
  }) {
    final bool step2Active = stage >= 2;
    final bool step3Active = stage >= 3;

    final Color activeStepColor = AppTheme.statusTeal;
    final Color currentStep2Color = isRecoveredWaitingConfirm
        ? AppTheme.statusTeal
        : AppTheme.statusRecovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Step 1 Circle: Gangguan Terdeteksi
          _buildStepCircle(
            isCompleted: true,
            isCurrent: stage == 1,
            activeColor: stage == 1 ? _textSecondary : activeStepColor,
            icon: Icons.warning,
          ),
          // Connector 1 -> 2
          Expanded(
            child: Container(
              height: 2,
              color: step2Active
                  ? (stage == 3 ? activeStepColor : currentStep2Color)
                  : _borderSubtle,
            ),
          ),
          // Step 2 Circle: Perbaikan
          _buildStepCircle(
            isCompleted: stage >= 3,
            isCurrent: stage == 2,
            activeColor: stage >= 3 ? activeStepColor : currentStep2Color,
            icon: stage >= 3 ? Icons.check_rounded : Icons.build_rounded,
          ),
          // Connector 2 -> 3
          Expanded(
            child: Container(
              height: 2,
              color: step3Active ? activeStepColor : _borderSubtle,
            ),
          ),
          // Step 3 Circle: Terkonfirmasi / Selesai
          _buildStepCircle(
            isCompleted: step3Active,
            isCurrent: step3Active,
            activeColor: activeStepColor,
            icon: Icons.task_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required bool isCompleted,
    required bool isCurrent,
    required Color activeColor,
    required IconData icon,
  }) {
    final bool lit = isCompleted || isCurrent;
    final Color bgColor = lit
        ? activeColor.withValues(alpha: 0.15)
        : _bgSurface;
    final Color borderColor = lit ? activeColor.withValues(alpha: 0.4) : _borderSubtle;
    final Color fgColor = lit ? activeColor : _textHint;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: lit ? 1.5 : 1.0),
      ),
      child: Center(
        child: Icon(icon, size: 15, color: fgColor),
      ),
    );
  }

  Widget _buildChipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _textHint),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}