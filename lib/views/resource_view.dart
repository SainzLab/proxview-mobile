import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../viewmodels/network_viewmodel.dart';
import '../viewmodels/proxmox_viewmodel.dart';
import 'network_targets_view.dart';
import 'proxmox_view.dart';

class ResourceView extends StatefulWidget {
  const ResourceView({super.key});

  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> {
  int _selectedCategory = 0; // 0 = Cluster Proxmox, 1 = Target Jaringan

  // Adaptive Theme Colors
  static Color get _bgMain => AppTheme.bgMain;
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;
  static Color get _textHint => AppTheme.textHint;

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    final pveVm = context.watch<ProxmoxViewModel>();
    final netVm = context.watch<NetworkViewModel>();

    // 1. Data Node Fisik
    final totalNodes = pveVm.nodeStatuses.length;
    final onlineNodes = pveVm.nodeStatuses.where((n) => n.isOnline).length;

    // 2. Data VM (QEMU) & LXC (Container)
    final totalVms = pveVm.resources.vms.length;
    final runningVms = pveVm.resources.vms.where((v) => v.isRunning).length;

    final totalLxcs = pveVm.resources.lxcs.length;
    final runningLxcs = pveVm.resources.lxcs.where((l) => l.isRunning).length;

    final totalGuests = totalVms + totalLxcs;
    final runningGuests = runningVms + runningLxcs;
    final stoppedGuests = totalGuests - runningGuests;

    // 3. Data Storage Cluster
    final totalStorages = pveVm.resources.storages.length;
    final activeStorages =
        pveVm.resources.storages.where((s) => s.isActive).length;
    final inactiveStorages = totalStorages - activeStorages;

    // 4. Data Target Jaringan
    final totalTargets = netVm.allTargets.length;
    final upTargets = netVm.allTargets.where((t) => t.isUp).length;
    final downTargets = totalTargets - upTargets;
    final icmpCount = netVm.allTargets
        .where((t) => t.protocol.toUpperCase().contains('ICMP'))
        .length;
    final tcpCount = netVm.allTargets
        .where((t) => t.protocol.toUpperCase().contains('TCP'))
        .length;

    final hasProxmoxAlert =
        onlineNodes < totalNodes || stoppedGuests > 0 || inactiveStorages > 0;
    final hasNetworkAlert = upTargets < totalTargets;

    return Column(
      children: [
        Container(
          color: _bgMain,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  index: 0,
                  icon: Icons.dns_rounded,
                  title: 'PROXMOX',
                  primaryStat: '$onlineNodes/$totalNodes Node Online',
                  secondaryStat:
                      'VM/LXC: $runningGuests Aktif • $stoppedGuests Non-Aktif',
                  tertiaryStat:
                      'Storage: $activeStorages Aktif • $inactiveStorages Non-Aktif',
                  accentColor: AppTheme.statusTeal, // Emerald
                  hasAlert: hasProxmoxAlert,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryCard(
                  index: 1,
                  icon: Icons.router_rounded,
                  title: 'ICMP & TCP',
                  primaryStat: '$upTargets/$totalTargets Target UP',
                  secondaryStat: downTargets > 0
                      ? '$downTargets Target Gangguan'
                      : 'Semua Target Normal',
                  tertiaryStat: '$icmpCount ICMP • $tcpCount TCP Socket',
                  accentColor: Colors.blue, // Blue accent for TCP/ICMP separation
                  hasAlert: hasNetworkAlert,
                ),
              ),
            ],
          ),
        ),
        Divider(color: _borderSubtle, height: 1),
        Expanded(
          child: Container(
            color: _bgMain,
            child: IndexedStack(
              index: _selectedCategory,
              children: const [
                ProxmoxView(summaryOnly: true),
                NetworkTargetsView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required int index,
    required IconData icon,
    required String title,
    required String primaryStat,
    required String secondaryStat,
    String? tertiaryStat,
    required Color accentColor,
    required bool hasAlert,
  }) {
    final isSelected = _selectedCategory == index;
    final effectiveColor = hasAlert ? AppTheme.statusDown : accentColor;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.1)
              : _bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.5)
                : _borderSubtle,
            width: isSelected ? 1.3 : 1.0,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? effectiveColor.withValues(alpha: 0.2)
                        : _bgMain,
                    border: Border.all(
                        color: isSelected ? Colors.transparent : _borderSubtle),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: isSelected ? effectiveColor : _textHint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? effectiveColor : _textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              primaryStat,
              style: TextStyle(
                color: isSelected ? _textMain : _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              secondaryStat,
              style: TextStyle(
                color: hasAlert ? AppTheme.statusDown : _textMuted,
                fontSize: 9.5,
                fontWeight: hasAlert ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (tertiaryStat != null) ...[
              const SizedBox(height: 2),
              Text(
                tertiaryStat,
                style: TextStyle(
                  color: _textHint,
                  fontSize: 9,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}