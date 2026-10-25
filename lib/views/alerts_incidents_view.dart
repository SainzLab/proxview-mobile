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
          matchesFilter = a.severity.toUpperCase() == _selectedFilter.toUpperCase();
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
          matchesFilter = t.severity.toUpperCase() == _selectedFilter.toUpperCase();
        }
      }
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlertIncidentViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final currentUserName = authVm.currentUser?.name;

    final filteredActive = _filterAlerts(vm.activeAlerts);
    final filteredIncidents = _filterIncidents(vm.incidents);
    final filteredHistory = _filterAlerts(vm.historyAlerts);

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildIncidentStatsChart(vm.incidentStats),
                  Container(
                    color: AppTheme.background,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SegmentedTabBar(
                      tabs: [
                        Tab(text: 'AKTIF (${vm.activeAlerts.length})'),
                        Tab(text: 'TIKET (${vm.incidents.length})'),
                        Tab(text: 'RIWAYAT (${vm.historyAlerts.length})'),
                      ],
                    ),
                  ),
                  Container(
                    color: AppTheme.background,
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
                              color: AppTheme.surfaceBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                dropdownColor: AppTheme.elevatedBackground,
                                borderRadius: BorderRadius.circular(12),
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                isExpanded: true,
                                style: const TextStyle(
                                  color: Colors.white,
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
                                                  : Colors.white70,
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
          ];
        },
        body: vm.isLoading && vm.activeAlerts.isEmpty && vm.incidents.isEmpty
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
                        emptyLabel: 'Tidak ada gangguan aktif saat ini.',
                        isActiveTab: true,
                        onLoadMore: () => vm.loadMoreActiveAlerts(),
                      ),
                      _buildIncidentsList(
                        context,
                        vm,
                        filteredIncidents,
                        currentUserName,
                        onLoadMore: () => vm.loadMoreIncidents(),
                      ),
                      _buildAlertsList(
                        context,
                        vm,
                        filteredHistory,
                        currentUserName: currentUserName,
                        emptyLabel: 'Belum ada riwayat gangguan selesai.',
                        isActiveTab: false,
                        onLoadMore: () => vm.loadMoreHistoryAlerts(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildIncidentStatsChart(IncidentStatsModel stats) {
    final int sumSegments = stats.down +
        stats.critical +
        stats.warning +
        stats.progress +
        stats.resolved;

    final items = [
      (
        label: 'DOWN',
        filterKey: 'DOWN',
        count: stats.down,
        color: AppTheme.statusDown,
      ),
      (
        label: 'CRITICAL',
        filterKey: 'CRITICAL',
        count: stats.critical,
        color: AppTheme.statusCritical,
      ),
      (
        label: 'WARNING',
        filterKey: 'WARNING',
        count: stats.warning,
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
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.statusTeal,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'RINGKASAN STATUS INSIDEN',
                      style: TextStyle(
                        color: Colors.white,
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
                      color: Colors.white70,
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
                child: sumSegments <= 0
                    ? Container(color: Colors.white10)
                    : Row(
                        children: items
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
                              ? item.color.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? item.color
                                : item.color.withValues(alpha: 0.22),
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
                                style: const TextStyle(
                                  color: Colors.white,
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white54,
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
    required String emptyLabel,
    required bool isActiveTab,
    VoidCallback? onLoadMore,
  }) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
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
    required bool isActiveTab,
  }) {
    final color = AppTheme.severityColor(alert.severity);
    final isCall = alert.isEmergencyCall;

    final bool hasJoined = currentUserName != null &&
        alert.technicians != null &&
        alert.technicians!.contains(currentUserName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveTab ? color.withValues(alpha: 0.35) : AppTheme.borderSubtle,
        ),
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
                      '${alert.targetType} • ${alert.actionType.toUpperCase()}',
                      style: TextStyle(
                        color: isCall ? AppTheme.statusDown : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.targetName,
                      style: const TextStyle(
                        color: Colors.white,
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
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppTheme.borderSubtle, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    Formatters.formatDateTime(alert.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white38),
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
          if (isActiveTab) ...[
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
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Colors.white24),
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
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      disabledBackgroundColor: Colors.white10,
                      disabledForegroundColor: Colors.white24,
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
    VoidCallback? onLoadMore,
  }) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
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
                  final color = AppTheme.severityColor(ticket.severity);
                  final bool hasJoined = currentUserName != null &&
                      ticket.technicians != null &&
                      ticket.technicians!.contains(currentUserName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !ticket.isResolved
                            ? color.withValues(alpha: 0.35)
                            : AppTheme.borderSubtle,
                      ),
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
                                      style: const TextStyle(
                                        color: Colors.white,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.title,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: AppTheme.borderSubtle, height: 1),
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
                        if (!ticket.isResolved) ...[
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
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    side: const BorderSide(color: Colors.white24),
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
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    disabledBackgroundColor: Colors.white10,
                                    disabledForegroundColor: Colors.white24,
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

  Widget _buildChipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}