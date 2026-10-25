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

  @override
  Widget build(BuildContext context) {
    final pveVm = context.watch<ProxmoxViewModel>();
    final netVm = context.watch<NetworkViewModel>();

    final totalNodes = pveVm.nodeStatuses.length;
    final onlineNodes = pveVm.nodeStatuses.where((n) => n.isOnline).length;
    final totalGuests =
        pveVm.resources.vms.length + pveVm.resources.lxcs.length;
    final runningGuests =
        pveVm.resources.vms.where((v) => v.isRunning).length +
        pveVm.resources.lxcs.where((l) => l.isRunning).length;

    final totalTargets = netVm.allTargets.length;
    final upTargets = netVm.allTargets.where((t) => t.isUp).length;

    return Column(
      children: [
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  index: 0,
                  icon: Icons.dns_rounded,
                  title: 'CLUSTER PROXMOX',
                  primaryStat: '$onlineNodes/$totalNodes Node',
                  secondaryStat: '$runningGuests/$totalGuests Guest Aktif',
                  accentColor: AppTheme.statusTeal,
                  hasAlert: onlineNodes < totalNodes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryCard(
                  index: 1,
                  icon: Icons.router_rounded,
                  title: 'JARINGAN ICMP & TCP',
                  primaryStat: '$upTargets/$totalTargets UP',
                  secondaryStat:
                      '${totalTargets - upTargets} Target Gangguan',
                  accentColor: AppTheme.statusRecovered,
                  hasAlert: upTargets < totalTargets,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppTheme.borderSubtle, height: 1),
        Expanded(
          child: IndexedStack(
            index: _selectedCategory,
            children: const [
              ProxmoxView(),
              NetworkTargetsView(),
            ],
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
              ? effectiveColor.withValues(alpha: 0.14)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.6)
                : AppTheme.borderSubtle,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: effectiveColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              secondaryStat,
              style: TextStyle(
                color: hasAlert ? AppTheme.statusDown : Colors.white54,
                fontSize: 10.5,
                fontWeight: hasAlert ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
