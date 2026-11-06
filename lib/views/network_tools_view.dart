import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/network_target_model.dart';
import '../models/network_tool_model.dart';
import '../services/api_service.dart';
import '../viewmodels/network_tools_viewmodel.dart';
import '../viewmodels/network_viewmodel.dart';
import 'common_widgets.dart';

class NetworkToolsView extends StatefulWidget {
  const NetworkToolsView({super.key});

  @override
  State<NetworkToolsView> createState() => _NetworkToolsViewState();
}

class _NetworkToolsViewState extends State<NetworkToolsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _targetController = TextEditingController();
  int _lastExternalRevision = -1;

  static const List<NetworkToolType> _tools = NetworkToolType.values;

  static const List<String> _ipv4Prefixes = [
    '/24',
    '/25',
    '/26',
    '/27',
    '/28',
    '/29',
    '/30',
    '/32',
    '/16',
    '/64',
  ];

  @override
  void initState() {
    super.initState();
    final vm = context.read<NetworkToolsViewModel>();
    _lastExternalRevision = vm.externalTargetRevision;

    _targetController.text = vm.currentInput;
    _tabController = TabController(
      length: _tools.length,
      vsync: this,
      initialIndex: _tools.indexOf(vm.selectedTool),
    );

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final vm = context.read<NetworkToolsViewModel>();
      final nextTool = _tools[_tabController.index];
      if (vm.selectedTool != nextTool) {
        vm.setSelectedTool(nextTool);
        _syncControllerText(vm.inputFor(nextTool));
      }
    }
  }

  void _syncControllerText(String text) {
    if (_targetController.text != text) {
      _targetController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _handleExecute(NetworkToolsViewModel vm) async {
    FocusScope.of(context).unfocus();
    final outcome = await vm.executeCurrentTool();
    if (!mounted) return;

    if (!outcome.ok &&
        outcome.feedbackMessage != null &&
        outcome.feedbackMessage!.isNotEmpty) {
      AppFeedback.showSnackBar(
        context,
        message: outcome.feedbackMessage!,
        isError: !outcome.ok && !outcome.isWarning,
        isWarning: !outcome.ok && outcome.isWarning,
      );
    }
  }

  void _showMonitoredTargetsPicker(
    BuildContext context,
    NetworkToolsViewModel toolsVm,
  ) {
    final netVm = context.read<NetworkViewModel>();
    final targets = netVm.allTargets;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final colors = AppTheme.of(sheetCtx);
        return BottomSheetContainer(
          height: MediaQuery.of(sheetCtx).size.height * 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih dari Target Terdaftar',
                style: TextStyle(
                  color: colors.textMain,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Klik salah satu perangkat di bawah untuk mengisi alamat IP/Host secara otomatis.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: targets.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada daftar target jaringan terdaftar.',
                          style: TextStyle(
                              color: colors.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: targets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final NetworkTargetModel t = targets[idx];
                          final isUp = t.isUp;
                          final statusColor =
                              isUp ? AppTheme.statusTeal : AppTheme.statusDown;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              String selectedIp = t.ipAddress.trim();
                              if (toolsVm.selectedTool ==
                                      NetworkToolType.ipScan &&
                                  NetworkToolValidator.isValidIpv4(
                                      selectedIp) &&
                                  toolsVm.ipScanPrefix == '/24') {
                                final parts = selectedIp.split('.');
                                selectedIp =
                                    '${parts[0]}.${parts[1]}.${parts[2]}.0';
                              }

                              toolsVm.setInput(selectedIp);
                              _syncControllerText(selectedIp);
                              Navigator.of(sheetCtx).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colors.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: colors.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    t.protocol
                                            .toUpperCase()
                                            .contains('TCP')
                                        ? Icons.settings_ethernet_rounded
                                        : Icons.network_ping_rounded,
                                    size: 18,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.name,
                                          style: TextStyle(
                                            color: colors.textMain,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t.ipAddress,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(
                                    label: t.status,
                                    color: statusColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final vm = context.watch<NetworkToolsViewModel>();

    // Sinkronisasi tab & teks jika ada pengiriman target dari halaman lain
    final desiredTabIdx = _tools.indexOf(vm.selectedTool);
    if (_lastExternalRevision != vm.externalTargetRevision) {
      _lastExternalRevision = vm.externalTargetRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_tabController.index != desiredTabIdx) {
          _tabController.animateTo(desiredTabIdx);
        }
        _syncControllerText(vm.currentInput);
      });
    }

    final tool = vm.selectedTool;
    final effectiveTarget = vm.buildEffectiveTarget(tool);
    final result = vm.currentResult;
    final errorStr = vm.currentError;

    return Column(
      children: [
        Container(
          color: colors.bgMain,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedTabBar(
            controller: _tabController,
            onTap: (idx) {
              final nextTool = _tools[idx];
              if (vm.selectedTool != nextTool) {
                vm.setSelectedTool(nextTool);
                _syncControllerText(vm.inputFor(nextTool));
              }
            },
            tabs: const [
              Tab(text: 'PING'),
              Tab(text: 'TRACEROUTE'),
              Tab(text: 'IP SCAN'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _buildInputCard(context, colors, vm, tool, effectiveTarget),
              const SizedBox(height: 20),
              const SectionTitle(
                title: 'OUTPUT',
                icon: Icons.terminal_rounded,
              ),
              const SizedBox(height: 10),
              _buildTerminalConsoleCard(
                context,
                colors,
                vm,
                tool,
                result,
                errorStr,
              ),
              if (vm.history.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionTitle(
                  title: 'RIWAYAT',
                  icon: Icons.history_rounded,
                  trailing: InkWell(
                    onTap: vm.clearHistory,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'BERSIHKAN',
                        style: TextStyle(
                          color: AppTheme.statusDown,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...vm.history.take(6).map(
                      (item) => _buildHistoryItem(colors, vm, item),
                    ),
              ],
              const SizedBox(height: 36),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(
    BuildContext context,
    ProxViewThemeColors colors,
    NetworkToolsViewModel vm,
    NetworkToolType tool,
    String effectiveTarget,
  ) {
    final isIpScan = tool == NetworkToolType.ipScan;
    final hasExplicitSlash = vm.currentInput.contains('/');

    final List<String> presets = isIpScan
        ? const ['192.168.1.0', '192.168.8.0', '10.0.0.0', '2001:db8::/64']
        : const ['8.8.8.8', '1.1.1.1', 'google.com', '2001:4860:4860::8888'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.statusTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.statusTeal.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  tool == NetworkToolType.ping
                      ? Icons.network_ping_rounded
                      : (tool == NetworkToolType.traceroute
                          ? Icons.alt_route_rounded
                          : Icons.radar_rounded),
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
                      tool.fullTitle,
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderColor),
            ),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(
                    color: AppTheme.statusTeal,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Expanded(
                  child: Text(
                    tool.commandPreview(effectiveTarget),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isIpScan
                      ? 'SUBNET / IP'
                      : 'HOST / DOMAIN',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showMonitoredTargetsPicker(context, vm),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 13,
                        color: AppTheme.statusTeal,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Pilih Target Terdaftar',
                        style: TextStyle(
                          color: AppTheme.statusTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetController,
                  enabled: !vm.isRunning,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _handleExecute(vm),
                  onChanged: (val) => vm.setInput(val),
                  style: TextStyle(
                    color: colors.textMain,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: AppTheme.statusTeal,
                  decoration: InputDecoration(
                    hintText: isIpScan
                        ? 'Contoh: 192.168.1.0 atau 2001:db8::/64'
                        : 'Contoh: 8.8.8.8, google.com, 2001:4860::8888',
                    hintStyle: TextStyle(
                      color: colors.textHint,
                      fontSize: 12.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Icon(
                      Icons.language_rounded,
                      color: colors.textMuted,
                      size: 19,
                    ),
                    suffixIcon: vm.currentInput.isNotEmpty && !vm.isRunning
                        ? IconButton(
                            onPressed: () {
                              _targetController.clear();
                              vm.setInput('');
                            },
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor:
                        colors.isDark ? colors.bgSurface : colors.bgMain,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.borderColor),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.statusTeal,
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
              if (isIpScan && !hasExplicitSlash) ...[
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.isDark ? colors.bgSurface : colors.bgMain,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _ipv4Prefixes.contains(vm.ipScanPrefix)
                          ? vm.ipScanPrefix
                          : '/24',
                      dropdownColor: colors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      items: _ipv4Prefixes
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p),
                            ),
                          )
                          .toList(),
                      onChanged: vm.isRunning
                          ? null
                          : (val) {
                              if (val != null) vm.setIpScanPrefix(val);
                            },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: presets.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: vm.isRunning
                        ? null
                        : () {
                            vm.setInput(preset);
                            _syncControllerText(preset);
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.borderColor),
                      ),
                      child: Text(
                        preset,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (vm.isRunning)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.statusTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            AppTheme.statusTeal.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.statusTeal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Menjalankan ${vm.runningTool?.label ?? tool.label}... (${vm.elapsedSeconds}d)',
                            style: const TextStyle(
                              color: AppTheme.statusTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: vm.cancelExecution,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.statusDown,
                    side: BorderSide(
                      color: AppTheme.statusDown.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BATAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleExecute(vm),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'JALANKAN ${tool.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTerminalConsoleCard(
    BuildContext context,
    ProxViewThemeColors colors,
    NetworkToolsViewModel vm,
    NetworkToolType tool,
    NetworkToolResponse? result,
    String? errorStr,
  ) {
    final bool isRunningActiveTool = vm.isRunning && vm.runningTool == tool;
    final rawOutput = result?.output.trim() ?? '';
    final parsedErr =
        errorStr != null ? ApiException.parse(errorStr) : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF26334D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal Header Bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Color(0xFF26334D))),
            ),
            child: Row(
              children: [
                _terminalDot(const Color(0xFFF43F5E)),
                const SizedBox(width: 6),
                _terminalDot(const Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                _terminalDot(const Color(0xFF10B981)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'srv% ${tool.label.toLowerCase()}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (rawOutput.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    tooltip: 'Salin Output Terminal',
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: rawOutput));
                      if (context.mounted) {
                        AppFeedback.showSnackBar(
                          context,
                          message:
                              'Output terminal berhasil disalin ke clipboard.',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
                if (result != null || errorStr != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    tooltip: 'Bersihkan Konsol',
                    onPressed: vm.clearCurrentConsole,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Terminal Body
          ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: 190, maxHeight: 380),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: isRunningActiveTool
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppTheme.statusTeal,
                            strokeWidth: 2.2,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Menunggu hasil stdout dari server (${vm.elapsedSeconds} detik)...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    )
                  : rawOutput.isNotEmpty
                      ? Scrollbar(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SelectableText(
                                rawOutput,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        )
                      : parsedErr != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 20,
                                ),
                                child: Text(
                                  '[Error] ${parsedErr.message}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.statusDown,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                  'Masukkan alamat target lalu tekan JALANKAN\nuntuk melihat output konsol dari server.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _terminalDot(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildHistoryItem(
    ProxViewThemeColors colors,
    NetworkToolsViewModel vm,
    NetworkToolResponse item,
  ) {
    final statusColor =
        item.success ? AppTheme.statusTeal : AppTheme.statusWarning;
    final toolLabel = item.toolType?.label ?? 'TOOL';
    final targetStr = item.target ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: vm.isRunning
            ? null
            : () {
                if (item.toolType != null) {
                  final idx = _tools.indexOf(item.toolType!);
                  if (idx >= 0 && _tabController.index != idx) {
                    _tabController.animateTo(idx);
                  }
                  vm.setSelectedTool(item.toolType!);
                  if (item.target != null) {
                    vm.setInput(item.target!, tool: item.toolType!);
                    _syncControllerText(item.target!);
                  }
                }
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  toolLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetStr,
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message.isNotEmpty
                          ? item.message
                          : Formatters.formatDateTime(
                              item.timestamp.toIso8601String(),
                            ),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatTimeSeconds(
                    item.timestamp.toIso8601String()),
                style: TextStyle(
                  color: colors.textHint,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}