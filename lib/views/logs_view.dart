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
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: TabBar(
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
                tabs: [
                  Tab(text: 'TASKS (${filteredTasks.length})'),
                  Tab(text: 'CLUSTER (${filteredCluster.length})'),
                  Tab(text: 'SISTEM (${filteredSystem.length})'),
                ],
              ),
            ),
          ),
          Container(
            color: AppTheme.background,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              cursorColor: AppTheme.statusTeal,
              decoration: InputDecoration(
                hintText: 'Cari log (tipe, node, user, status, pesan)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: _clearSearch,
                        tooltip: 'Hapus pencarian',
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceBackground,
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.white12),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onClearSearch != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.statusTeal),
                  label: const Text(
                    'Hapus Pencarian',
                    style: TextStyle(
                      color: AppTheme.statusTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
      ],
    );
  }

  Widget _buildTasksTab(
    BuildContext context,
    LogViewModel vm,
    List<ProxmoxTaskLogModel> tasks,
  ) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // Deteksi ketika user scroll mentok ke bawah
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // TODO: Pastikan metode ini ada di LogViewModel Anda
            // vm.loadMoreTasks(); 
          }
          return false;
        },
        child: vm.taskLogs.isEmpty
            ? _buildEmptyState('Tidak ada riwayat task Proxmox.', Icons.task_alt)
            : tasks.isEmpty
                ? _buildEmptyState(
                    'Tidak ada task yang cocok dengan "$_searchQuery".',
                    Icons.search_off,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tasks.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.statusTeal)),
                        );
                      }

                      final task = tasks[index];
                  final isOk = task.isOk;
                  final badgeLabel = isOk ? task.status : 'ERROR';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _showTaskTerminalSheet(context, task),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBackground,
                          borderRadius: BorderRadius.circular(14),
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
                                color: isOk
                                    ? AppTheme.statusTeal.withValues(alpha: 0.1)
                                    : AppTheme.statusDown.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOk ? Icons.check_circle_outline : Icons.error_outline,
                                color: isOk ? AppTheme.statusTeal : AppTheme.statusDown,
                                size: 22,
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(text: '•  User: '),
                                        TextSpan(
                                          text: task.user,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: Colors.white38),
                                      const SizedBox(width: 4),
                                      Text(
                                        Formatters.formatDateTime(task.startTime),
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (!isOk && task.status.toUpperCase() != 'ERROR') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.statusDown.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.statusDown.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        task.status,
                                        style: TextStyle(
                                          color: AppTheme.statusDown.withValues(alpha: 0.9),
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
                              color: isOk ? AppTheme.statusTeal : AppTheme.statusDown,
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
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${task.type.toUpperCase()} • ${task.node}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
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
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: lines.length,
                              itemBuilder: (context, idx) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  lines[idx],
                                  style: const TextStyle(
                                    color: Color(0xFF00FF00),
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.4,
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
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // TODO: Tambahkan metode loadMoreClusterLogs() di LogViewModel
            // vm.loadMoreClusterLogs();
          }
          return false;
        },
        child: vm.clusterLogs.isEmpty
            ? _buildEmptyState('Tidak ada log cluster Proxmox.', Icons.dns_outlined)
            : logs.isEmpty
                ? _buildEmptyState(
                    'Tidak ada log cluster yang cocok dengan "$_searchQuery".',
                    Icons.search_off,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.statusTeal)),
                        );
                      }

                      final log = logs[index];
                  final isErr = log.isError;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isErr
                          ? AppTheme.statusDown.withValues(alpha: 0.04)
                          : AppTheme.surfaceBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isErr
                            ? AppTheme.statusDown.withValues(alpha: 0.3)
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isErr
                                ? AppTheme.statusDown.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isErr ? Icons.warning_amber_rounded : Icons.info_outline,
                            color: isErr ? AppTheme.statusDown : Colors.white70,
                            size: 20,
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
                                  color: isErr ? Colors.red.shade200 : Colors.white,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: isErr ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildMiniChip(Icons.computer, log.node),
                                  const SizedBox(width: 8),
                                  _buildMiniChip(Icons.settings_applications, log.tag),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Formatters.formatDateTime(log.time),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
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
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchLogs(showLoading: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!vm.isLoadingMore &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50) {
            // TODO: Tambahkan metode loadMoreSystemLogs() di LogViewModel
            // vm.loadMoreSystemLogs();
          }
          return false;
        },
        child: vm.systemLogs.isEmpty
            ? _buildEmptyState('Tidak ada log audit sistem.', Icons.admin_panel_settings_outlined)
            : logs.isEmpty
                ? _buildEmptyState(
                    'Tidak ada log audit yang cocok dengan "$_searchQuery".',
                    Icons.search_off,
                    onClearSearch: _clearSearch,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length + (vm.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.statusTeal)),
                        );
                      }

                      final item = logs[index];
                  final color = AppTheme.severityColor(item.level);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
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
                                        letterSpacing: 1.0,
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
                                const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white38),
                                const SizedBox(width: 4),
                                Text(
                                  Formatters.formatDateTime(item.timestamp),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}