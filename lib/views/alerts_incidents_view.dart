import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/alert_incident_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import 'common_widgets.dart';

class AlertsIncidentsView extends StatelessWidget {
  const AlertsIncidentsView({super.key});

  Future<void> _handleJoin(BuildContext context, int alertId) async {
    final vm = context.read<AlertIncidentViewModel>();
    final res = await vm.joinAlert(alertId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? Colors.teal : AppTheme.statusDown,
        ),
      );
    }
  }

  Future<void> _handleResolve(BuildContext context, int alertId) async {
    final vm = context.read<AlertIncidentViewModel>();
    final res = await vm.resolveAlert(alertId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? Colors.teal : AppTheme.statusDown,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlertIncidentViewModel>();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: AppTheme.background,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              indicatorColor: AppTheme.statusTeal,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
              tabs: [
                Tab(text: 'AKTIF (${vm.activeAlerts.length})'),
                Tab(text: 'TIKET (${vm.incidents.length})'),
                Tab(text: 'RIWAYAT (${vm.historyAlerts.length})'),
              ],
            ),
          ),
          Expanded(
            child: vm.isLoading && vm.activeAlerts.isEmpty && vm.incidents.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : vm.errorMessage != null &&
                        vm.activeAlerts.isEmpty &&
                        vm.incidents.isEmpty
                    ? ErrorStateBox(
                        message: vm.errorMessage!,
                        onRetry: () => vm.fetchAll(showLoading: true),
                      )
                    : TabBarView(
                        children: [
                          _buildAlertsList(
                            context,
                            vm,
                            vm.activeAlerts,
                            emptyLabel: 'Tidak ada gangguan aktif saat ini.',
                            isActiveTab: true,
                          ),
                          _buildIncidentsList(context, vm),
                          _buildAlertsList(
                            context,
                            vm,
                            vm.historyAlerts,
                            emptyLabel: 'Belum ada riwayat gangguan yang selesai.',
                            isActiveTab: false,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(
    BuildContext context,
    AlertIncidentViewModel vm,
    List<AlertModel> list, {
    required String emptyLabel,
    required bool isActiveTab,
  }) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchAll(showLoading: false),
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.verified_outlined,
                  color: AppTheme.statusTeal.withValues(alpha: 0.6),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    emptyLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final alert = list[index];
                return _buildAlertCard(context, vm, alert, isActiveTab: isActiveTab);
              },
            ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    AlertIncidentViewModel vm,
    AlertModel alert, {
    required bool isActiveTab,
  }) {
    final color = AppTheme.severityColor(alert.severity);
    final isCall = alert.isEmergencyCall;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCall
                        ? Icons.ring_volume_rounded
                        : Icons.notifications_active_outlined,
                    size: 16,
                    color: isCall ? AppTheme.statusDown : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${alert.targetType} • ${alert.actionType.toUpperCase()}',
                    style: TextStyle(
                      color: isCall ? AppTheme.statusDown : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              StatusBadge(label: alert.severity, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.targetName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waktu: ${Formatters.formatDateTime(alert.createdAt)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                alert.isBeingHandled
                    ? 'Ditangani: ${alert.technicians ?? "-"}'
                    : 'Belum Ditangani',
                style: TextStyle(
                  color: alert.isBeingHandled
                      ? AppTheme.statusTeal
                      : AppTheme.statusWarning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isActiveTab) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.isSubmittingAction
                        ? null
                        : () => _handleJoin(context, alert.id),
                    icon: const Icon(Icons.handyman_outlined, size: 16),
                    label: Text(
                      alert.isBeingHandled ? 'IKUT TANGANI (JOIN)' : 'TANGANI (JOIN)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!alert.canResolve || vm.isSubmittingAction)
                        ? null
                        : () => _handleResolve(context, alert.id),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'SELESAI (RESOLVE)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusTeal,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white10,
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!alert.canResolve)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '*Tombol Resolve aktif otomatis setelah indikator target berstatus RECOVERED.',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncidentsList(BuildContext context, AlertIncidentViewModel vm) {
    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: () => vm.fetchAll(showLoading: false),
      child: vm.incidents.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'Belum ada tiket insiden.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: vm.incidents.length,
              itemBuilder: (context, index) {
                final ticket = vm.incidents[index];
                final color = AppTheme.severityColor(ticket.severity);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                          Text(
                            ticket.ticketCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          StatusBadge(
                            label: '${ticket.severity} • ${ticket.status}',
                            color: color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ticket.target,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildChipInfo(
                            Icons.timer_outlined,
                            'Downtime: ${ticket.downtimeDuration}',
                          ),
                          _buildChipInfo(
                            Icons.engineering_outlined,
                            'Penanganan: ${ticket.handlingDuration}',
                          ),
                          _buildChipInfo(
                            Icons.person_outline,
                            'Teknisi: ${ticket.technicians ?? "-"}',
                          ),
                        ],
                      ),
                      if (!ticket.isResolved) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: vm.isSubmittingAction
                                    ? null
                                    : () => _handleJoin(context, ticket.dbId),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                ),
                                child: const Text(
                                  'JOIN TIKET',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (!ticket.canResolve || vm.isSubmittingAction)
                                    ? null
                                    : () => _handleResolve(context, ticket.dbId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.statusTeal,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.white10,
                                ),
                                child: const Text(
                                  'RESOLVE TIKET',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildChipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
