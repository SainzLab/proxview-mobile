import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/proxmox_model.dart';
import '../viewmodels/proxmox_viewmodel.dart';
import 'common_widgets.dart';

class ProxmoxView extends StatefulWidget {
  const ProxmoxView({super.key});

  @override
  State<ProxmoxView> createState() => _ProxmoxViewState();
}

class _ProxmoxViewState extends State<ProxmoxView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vm = context.read<ProxmoxViewModel>();
    _searchController.text = vm.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<ProxmoxViewModel>().setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProxmoxViewModel>();

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (vm.servers.isNotEmpty) _buildServerSelector(context, vm),
                  Container(
                    color: AppTheme.background,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SegmentedTabBar(
                      tabs: [
                        Tab(text: 'NODE (${vm.filteredNodes.length})'),
                        Tab(
                          text: 'VM & LXC (${vm.filteredVms.length + vm.filteredLxcs.length})',
                        ),
                        Tab(text: 'STORAGE (${vm.filteredStorages.length})'),
                      ],
                    ),
                  ),
                  Container(
                    color: AppTheme.background,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppSearchField(
                      controller: _searchController,
                      onChanged: vm.setSearchQuery,
                      onClear: _clearSearch,
                      hintText: 'Cari node, VM, LXC, atau storage...',
                      hasText: vm.searchQuery.isNotEmpty,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: vm.isLoading && vm.servers.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.statusTeal,
                  strokeWidth: 2.5,
                ),
              )
            : vm.errorMessage != null && vm.servers.isEmpty
                ? ErrorStateBox(
                    message: vm.errorMessage!,
                    onRetry: () => vm.fetchProxmoxData(showLoading: true),
                  )
                : TabBarView(
                    children: [
                      _buildNodesTab(context, vm),
                      _buildGuestsTab(context, vm),
                      _buildStoragesTab(context, vm),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptySearchState(String query, String category) {
    return EmptyStateBox(
      icon: Icons.search_off_rounded,
      message: 'Tidak ada $category yang cocok dengan "$query".',
      onAction: _clearSearch,
      actionLabel: 'Hapus Pencarian',
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return EmptyStateBox(
      icon: icon,
      message: message,
    );
  }

  Widget _buildServerSelector(BuildContext context, ProxmoxViewModel vm) {
    final selected = vm.selectedServer;
    if (selected == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.statusTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dns_rounded, color: AppTheme.statusTeal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selected.id,
                dropdownColor: AppTheme.elevatedBackground,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                isExpanded: true,
                items: vm.servers.map((server) {
                  return DropdownMenuItem<int>(
                    value: server.id,
                    child: Text(
                      '${server.name} (PVE ${server.pveVersion} • ${server.latency})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final target = vm.servers.firstWhere((s) => s.id == id);
                  vm.selectServer(target);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodesTab(BuildContext context, ProxmoxViewModel vm) {
    final nodes = vm.filteredNodes;

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchProxmoxData(showLoading: false),
      child: nodes.isEmpty
          ? (vm.searchQuery.isNotEmpty
              ? _buildEmptySearchState(vm.searchQuery, 'node')
              : _buildEmptyState('Tidak ada data node fisik.', Icons.dns_outlined))
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              itemCount: nodes.length,
              itemBuilder: (context, index) => _buildNodeCard(nodes[index]),
            ),
    );
  }

  Widget _buildNodeCard(ProxmoxNodeStatusModel node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.nodeName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'UPTIME: ${node.uptime}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(label: node.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${node.cpuModel} (${node.cpuCores} Core)',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppTheme.borderSubtle, height: 1),
          ),
          ModernProgressBar(
            label: 'Penggunaan CPU',
            percentage: node.cpuPercentValue,
            color: Colors.white,
            customTrailingText: node.cpuUsage,
          ),
          const SizedBox(height: 16),
          ModernProgressBar(
            label: 'RAM (${node.ramUsed} / ${node.ramTotal})',
            percentage: node.ramPercentValue,
            color: AppTheme.statusTeal,
            customTrailingText: node.ramPercentage,
          ),
          const SizedBox(height: 16),
          ModernProgressBar(
            label: 'IO Delay',
            percentage: node.ioDelayPercentValue,
            color: node.ioDelayPercentValue > 5.0
                ? AppTheme.statusCritical
                : AppTheme.statusWarning,
            customTrailingText: node.ioDelay,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Beban Rata-rata (Load)',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        node.loadAverage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: AppTheme.borderSubtle, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trafik Jaringan',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '↓ ${node.rxIn} • ↑ ${node.txOut}',
                        style: const TextStyle(
                          color: AppTheme.statusTeal,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestsTab(BuildContext context, ProxmoxViewModel vm) {
    final vms = vm.filteredVms;
    final lxcs = vm.filteredLxcs;

    if (vms.isEmpty && lxcs.isEmpty) {
      if (vm.searchQuery.isNotEmpty) {
        return _buildEmptySearchState(vm.searchQuery, 'VM atau LXC');
      }
      return _buildEmptyState('Tidak ada VM atau LXC.', Icons.computer_rounded);
    }

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchProxmoxData(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            title: 'MESIN VIRTUAL (QEMU) — ${vms.length}',
            icon: Icons.computer_rounded,
          ),
          const SizedBox(height: 12),
          if (vms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vm.searchQuery.isNotEmpty ? 'Tidak ada VM yang cocok.' : 'Tidak ada QEMU VM.',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...vms.map((g) => _buildGuestCard(context, g)),

          const SizedBox(height: 24),
          SectionTitle(
            title: 'KONTAINER (LXC) — ${lxcs.length}',
            icon: Icons.layers_rounded,
          ),
          const SizedBox(height: 12),
          if (lxcs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vm.searchQuery.isNotEmpty ? 'Tidak ada LXC yang cocok.' : 'Tidak ada LXC Container.',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...lxcs.map((g) => _buildGuestCard(context, g)),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildGuestCard(BuildContext context, ProxmoxGuestModel guest) {
    final isRunning = guest.isRunning;
    final accentColor = isRunning ? AppTheme.statusTeal : Colors.white38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showGuestDetailSheet(context, guest),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRunning
                  ? AppTheme.statusTeal.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle,
            ),
            boxShadow: isRunning
                ? [
                    BoxShadow(
                      color: AppTheme.statusTeal.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRunning
                      ? AppTheme.statusTeal.withValues(alpha: 0.14)
                      : AppTheme.surfaceBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  guest.type == 'qemu' ? Icons.computer_rounded : Icons.layers_rounded,
                  size: 20,
                  color: isRunning ? AppTheme.statusTeal : Colors.white54,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            guest.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isRunning ? Colors.white : Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${guest.vmid}',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${guest.node.toUpperCase()} • ${guest.cpuCores} vCPU • ${guest.ramUsed}/${guest.ramTotal}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                    label: guest.status,
                    color: isRunning ? AppTheme.statusTeal : AppTheme.statusDown,
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 6),
                    Text(
                      guest.cpuUsage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestDetailSheet(BuildContext context, ProxmoxGuestModel guest) {
    final isRunning = guest.isRunning;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return BottomSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? AppTheme.statusTeal.withValues(alpha: 0.15)
                          : AppTheme.surfaceBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      guest.type == 'qemu' ? Icons.computer_rounded : Icons.layers_rounded,
                      color: isRunning ? AppTheme.statusTeal : Colors.white54,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guest.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${guest.type.toUpperCase()} #${guest.vmid} • Node: ${guest.node}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(
                    label: guest.status,
                    color: isRunning ? AppTheme.statusTeal : AppTheme.statusDown,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ModernProgressBar(
                label: 'Penggunaan CPU (${guest.cpuCores} Core)',
                percentage: guest.cpuPercentValue,
                color: Colors.white,
                customTrailingText: guest.cpuUsage,
              ),
              const SizedBox(height: 18),
              ModernProgressBar(
                label: 'RAM (${guest.ramUsed} / ${guest.ramTotal})',
                percentage: guest.ramPercentValue,
                color: AppTheme.statusTeal,
                customTrailingText: guest.ramPercentage,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    if (guest.type == 'qemu')
                      _buildKeyValWidgetRow(
                        'Kapasitas Disk',
                        RichText(
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: guest.diskTotal,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: ' (Bootdisk)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _buildKeyValRow('Penggunaan Disk', '${guest.diskUsed} / ${guest.diskTotal}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppTheme.borderSubtle, height: 1),
                    ),
                    _buildKeyValRow('Trafik Jaringan', '↓ ${guest.netIn} • ↑ ${guest.netOut}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: AppTheme.borderSubtle, height: 1),
                    ),
                    _buildKeyValRow('Durasi Aktif (Uptime)', guest.uptime),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeyValRow(String key, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          key,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyValWidgetRow(String key, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          key,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: valueWidget,
          ),
        ),
      ],
    );
  }

  Widget _buildStoragesTab(BuildContext context, ProxmoxViewModel vm) {
    final storages = vm.filteredStorages;

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: AppTheme.statusTeal,
      onRefresh: () => vm.fetchProxmoxData(showLoading: false),
      child: storages.isEmpty
          ? (vm.searchQuery.isNotEmpty
              ? _buildEmptySearchState(vm.searchQuery, 'storage')
              : _buildEmptyState('Tidak ada data storage.', Icons.sd_storage_outlined))
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              itemCount: storages.length,
              itemBuilder: (context, index) {
                final st = storages[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.statusTeal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sd_storage_rounded,
                          color: AppTheme.statusTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              st.storage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Node: ${st.node} • Tipe: ${st.type}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            st.used,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'dari ${st.total}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}