import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/log_model.dart';
import '../viewmodels/log_viewmodel.dart';
import 'common_widgets.dart';

class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  Timer? _pollingTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Real-time update setiap 10 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        // Memperbarui data tanpa menampilkan indikator loading penuh
        context.read<LogViewModel>().fetchLogs(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  List<ProxmoxTaskLogModel> _filterTasks(List<ProxmoxTaskLogModel> tasks) {
    if (_searchQuery.trim().isEmpty) return tasks;
    final q = _searchQuery.trim().toLowerCase();
    return tasks.where((task) {
      final formattedTime = Formatters.formatDateTime(task.startTime).toLowerCase();
      return task.type.toLowerCase().contains(q) ||
          task.node.toLowerCase().contains(q) ||
          task.user.toLowerCase().contains(q) ||
          task.status.toLowerCase().contains(q) ||
          task.upid.toLowerCase().contains(q) ||
          formattedTime.contains(q);
    }).toList();
  }

  List<ProxmoxClusterLogModel> _filterClusterLogs(List<ProxmoxClusterLogModel> logs) {
    if (_searchQuery.trim().isEmpty) return logs;
    final q = _searchQuery.trim().toLowerCase();
    return logs.where((log) {
      final formattedTime = Formatters.formatDateTime(log.time).toLowerCase();
      return log.msg.toLowerCase().contains(q) ||
          log.node.toLowerCase().contains(q) ||
          log.tag.toLowerCase().contains(q) ||
          log.user.toLowerCase().contains(q) ||
          formattedTime.contains(q);
    }).toList();
  }

  List<SystemAuditLogModel> _filterSystemLogs(List<SystemAuditLogModel> logs) {
    if (_searchQuery.trim().isEmpty) return logs;
    final q = _searchQuery.trim().toLowerCase();
    return logs.where((item) {
      final formattedTime = Formatters.formatDateTime(item.timestamp).toLowerCase();
      return item.message.toLowerCase().contains(q) ||
          item.source.toLowerCase().contains(q) ||
          item.level.toLowerCase().contains(q) ||
          formattedTime.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LogViewModel>();
    final filteredTasks = _filterTasks(vm.taskLogs);
    final filteredCluster = _filterClusterLogs(vm.clusterLogs);
    final filteredSystem = _filterSystemLogs(vm.systemLogs);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppTheme.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedTabBar(
              tabs: [
                Tab(text: 'TASK (${filteredTasks.length})'),
                Tab(text: 'CLUSTER (${filteredCluster.length})'),
                Tab(text: 'AUDIT (${filteredSystem.length})'),
              ],
            ),
          ),
          Container(
            color: AppTheme.background,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppSearchField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              onClear: _clearSearch,
              hintText: 'Cari log (tipe, node, user, status, pesan)...',
              hasText: _searchQuery.isNotEmpty,
            ),
          ),
          Expanded(
            child: vm.isLoading &&
                    vm.taskLogs.isEmpty &&
                    vm.clusterLogs.isEmpty &&
                    vm.systemLogs.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.statusTeal,
                      strokeWidth: 2.5,
                    ),
                  )
                : vm.errorMessage != null &&
                        vm.taskLogs.isEmpty &&
                        vm.clusterLogs.isEmpty &&
                        vm.systemLogs.isEmpty
                    ? ErrorStateBox(
                        message: vm.errorMessage!,
                        onRetry: () => vm.fetchLogs(showLoading: true),
                      )
                    : TabBarView(
                        children: [
                          _buildTasksTab(context, vm, filteredTasks),
                          _buildClusterSyslogTab(context, vm, filteredCluster),
                          _buildSystemAuditTab(context, vm, filteredSystem),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    String message,
    IconData icon, {
    VoidCallback? onClearSearch,
  }) {
    return EmptyStateBox(
      icon: icon,
      message: message,
      onAction: onClearSearch,
      actionLabel: onClearSearch != null ? 'Hapus Pencarian' : null,
    );
  }

  Widget _buildTasksTab(
    BuildContext context,
    LogViewModel vm,
    List<ProxmoxTaskLogModel> tasks,
  ) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // Pagination hook
          }
          return false;
        },
        child: vm.taskLogs.isEmpty
            ? _buildEmptyState('Tidak ada riwayat task Proxmox.', Icons.task_alt_rounded)
            : tasks.isEmpty
                ? _buildEmptyState(
                    'Tidak ada task yang cocok dengan "$_searchQuery".',
                    Icons.search_off_rounded,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tasks.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.statusTeal),
                          ),
                        );
                      }

                      final task = tasks[index];
                      final isOk = task.isOk;
                      final badgeLabel = isOk ? task.status : 'ERROR';
                      final statusColor = isOk ? AppTheme.statusTeal : AppTheme.statusDown;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showTaskTerminalSheet(context, task),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isOk
                                    ? AppTheme.borderSubtle
                                    : AppTheme.statusDown.withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isOk
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.error_outline_rounded,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.type,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Node: '),
                                            TextSpan(
                                              text: '${task.node}  ',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const TextSpan(text: '•  User: '),
                                            TextSpan(
                                              text: task.user,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_rounded,
                                            size: 12,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            Formatters.formatDateTime(task.startTime),
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isOk && task.status.toUpperCase() != 'ERROR') ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.statusDown.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppTheme.statusDown.withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Text(
                                            task.status,
                                            style: const TextStyle(
                                              color: AppTheme.statusDown,
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: badgeLabel,
                                  color: statusColor,
                                  showDot: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showTaskTerminalSheet(BuildContext context, ProxmoxTaskLogModel task) {
    final vm = context.read<LogViewModel>();
    final terminalFuture = vm.fetchTaskDetail(node: task.node, upid: task.upid);
    final badgeLabel = task.isOk ? task.status : 'ERROR';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return FutureBuilder<List<String>>(
          future: terminalFuture,
          builder: (context, snapshot) {
            final lines = snapshot.data ?? [];
            return BottomSheetContainer(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.terminal_rounded,
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
                              task.type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Node: ${task.node} • User: ${task.user}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(
                        label: badgeLabel,
                        color: task.isOk ? AppTheme.statusTeal : AppTheme.statusDown,
                        showDot: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.statusTeal,
                              strokeWidth: 2,
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: lines.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada output log untuk task ini.',
                                      style: TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: lines.length,
                                    itemBuilder: (context, idx) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        lines[idx],
                                        style: const TextStyle(
                                          color: AppTheme.statusTeal,
                                          fontFamily: 'monospace',
                                          fontSize: 11.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClusterSyslogTab(
    BuildContext context,
    LogViewModel vm,
    List<ProxmoxClusterLogModel> logs,
  ) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // Pagination hook
          }
          return false;
        },
        child: vm.clusterLogs.isEmpty
            ? _buildEmptyState('Tidak ada log cluster Proxmox.', Icons.dns_outlined)
            : logs.isEmpty
                ? _buildEmptyState(
                    'Tidak ada log cluster yang cocok dengan "$_searchQuery".',
                    Icons.search_off_rounded,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.statusTeal),
                          ),
                        );
                      }

                      final log = logs[index];
                      final isErr = log.isError;
                      final statusColor = isErr ? AppTheme.statusDown : AppTheme.statusRecovered;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isErr
                                ? AppTheme.statusDown.withValues(alpha: 0.4)
                                : AppTheme.borderSubtle,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isErr
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline_rounded,
                                color: statusColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.msg,
                                    style: TextStyle(
                                      color: isErr ? AppTheme.statusDown : Colors.white,
                                      fontSize: 13,
                                      height: 1.4,
                                      fontWeight: isErr ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _buildMiniChip(Icons.computer_rounded, log.node),
                                      _buildMiniChip(Icons.settings_applications_rounded, log.tag),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        Formatters.formatDateTime(log.time),
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildSystemAuditTab(
    BuildContext context,
    LogViewModel vm,
    List<SystemAuditLogModel> logs,
  ) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // Pagination hook
          }
          return false;
        },
        child: vm.systemLogs.isEmpty
            ? _buildEmptyState('Tidak ada log audit sistem.', Icons.admin_panel_settings_outlined)
            : logs.isEmpty
                ? _buildEmptyState(
                    'Tidak ada log audit yang cocok dengan "$_searchQuery".',
                    Icons.search_off_rounded,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.statusTeal),
                          ),
                        );
                      }

                      final item = logs[index];
                      final color = AppTheme.severityColor(item.level);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: color, width: 4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.shield_outlined, size: 14, color: color),
                                        const SizedBox(width: 6),
                                        Text(
                                          item.source.toUpperCase(),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    StatusBadge(
                                      label: item.level.toUpperCase(),
                                      color: color,
                                      showDot: false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.white38,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      Formatters.formatDateTime(item.timestamp),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}