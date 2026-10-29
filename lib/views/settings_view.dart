import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'common_widgets.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _baseUrlController = TextEditingController();
  Map<String, dynamic>? _bgDiagnostics;
  bool _isLoadingDiagnostics = false;

  // Adaptive Theme Colors
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;
  static Color get _textHint => AppTheme.textHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      _baseUrlController.text = authVm.baseUrl;
      _fetchDiagnostics();
    });
  }

  Future<void> _fetchDiagnostics() async {
    if (!mounted) return;
    setState(() => _isLoadingDiagnostics = true);
    final diag = await NotificationService().getBackgroundDiagnostics();
    if (mounted) {
      setState(() {
        _bgDiagnostics = diag;
        _isLoadingDiagnostics = false;
      });
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final trimmed = _baseUrlController.text.trim();
    if (trimmed.isEmpty) {
      AppFeedback.showSnackBar(
        context,
        message: 'Alamat URL Server tidak boleh kosong.',
        isWarning: true,
      );
      return;
    }

    if (!StorageService.isValidServerUrl(trimmed)) {
      AppFeedback.showSnackBar(
        context,
        message:
            'Format URL Server tidak valid. Contoh: https://domain-anda.com atau http://192.168.1.10:7060',
        isWarning: true,
      );
      return;
    }

    final normalizedPreview = StorageService.normalizeBaseUrl(trimmed);
    final confirmed = await AppFeedback.showConfirmDialog(
      context,
      title: 'Simpan Konfigurasi Server?',
      message:
          'Endpoint API akan diperbarui ke "$normalizedPreview". Pastikan alamat server dapat diakses oleh perangkat ini.',
      confirmLabel: 'SIMPAN',
      accentColor: AppTheme.statusTeal,
      icon: Icons.dns_rounded,
    );
    if (!confirmed || !mounted) return;

    final authVm = context.read<AuthViewModel>();
    await authVm.updateBaseUrl(trimmed);
    if (mounted) {
      _baseUrlController.text = authVm.baseUrl;
      AppFeedback.showSnackBar(
        context,
        message: 'Endpoint Server berhasil diperbarui.',
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthViewModel authVm) async {
    final confirmed = await AppFeedback.showConfirmDialog(
      context,
      title: 'Keluar dari Sistem?',
      message:
          'Sesi aktif dan kredensial lokal akan dihapus dari perangkat ini. Anda perlu login kembali untuk memantau sistem.',
      confirmLabel: 'YA, KELUAR',
      accentColor: AppTheme.statusDown,
      icon: Icons.logout_rounded,
    );
    if (confirmed && context.mounted) {
      await authVm.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    final themeVm = context.watch<ThemeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        if (user != null) ...[
          const SectionTitle(
            title: 'PROFIL PENGGUNA',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.3), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.statusTeal.withValues(alpha: 0.1),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: AppTheme.statusTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              color: _textMain,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            style: TextStyle(color: _textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: user.role,
                      color: AppTheme.statusTeal,
                      showDot: false,
                    ),
                  ],
                ),
                if (user.tokenExpiresAt != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: _borderSubtle, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 15, color: _textHint),
                          const SizedBox(width: 6),
                          Text(
                            'Batas Waktu Sesi:',
                            style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        Formatters.formatDateTime(user.tokenExpiresAt),
                        style: TextStyle(
                          color: _textMain,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        const SectionTitle(
          title: 'TAMPILAN & TEMA',
          icon: Icons.palette_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (themeVm.isDarkMode ? AppTheme.statusWarning : AppTheme.statusTeal)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  themeVm.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: themeVm.isDarkMode ? AppTheme.statusWarning : AppTheme.statusTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Gelap (Dark Mode)',
                      style: TextStyle(
                        color: _textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      themeVm.isDarkMode
                          ? 'Tampilan gelap aktif (nyaman di ruangan redup)'
                          : 'Tampilan terang aktif',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: themeVm.isDarkMode,
                activeColor: AppTheme.statusTeal,
                onChanged: (val) => themeVm.setDarkMode(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const SectionTitle(
          title: 'KONFIGURASI SERVER',
          icon: Icons.router_outlined,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tentukan alamat endpoint API server ProxView yang sedang berjalan.',
                style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _baseUrlController,
                label: 'Base URL Server API',
                hint: 'http(s)://ip-atau-domain:port',
                icon: Icons.language_rounded,
                keyboardType: TextInputType.url,
                maxLength: 256,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveServerUrl,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text(
                    'SIMPAN PERUBAHAN',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontSize: 12.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.statusTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (!authVm.isKepalaBidang) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle(
                title: 'PEMATAUAN LATAR BELAKANG & KEANDALAN',
                icon: Icons.notifications_active_outlined,
              ),
              IconButton(
                onPressed: _isLoadingDiagnostics ? null : _fetchDiagnostics,
                tooltip: 'Segarkan Status Latar Belakang',
                icon: _isLoadingDiagnostics
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, size: 20, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ((_bgDiagnostics?['isServiceRunning'] == true &&
                                    _bgDiagnostics?['isEnabled'] == true)
                                ? AppTheme.statusTeal
                                : AppTheme.statusWarning)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (_bgDiagnostics?['isServiceRunning'] == true &&
                                _bgDiagnostics?['isEnabled'] == true)
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: (_bgDiagnostics?['isServiceRunning'] == true &&
                                _bgDiagnostics?['isEnabled'] == true)
                            ? AppTheme.statusTeal
                            : AppTheme.statusWarning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_bgDiagnostics?['isServiceRunning'] == true &&
                                    _bgDiagnostics?['isEnabled'] == true)
                                ? 'Foreground Service Aktif'
                                : 'Service Belum Berjalan',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Memeriksa gangguan & panggilan darurat setiap ~10 detik',
                            style: TextStyle(color: _textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: _borderSubtle, height: 1),
                ),
                _buildDiagnosticRow(
                  'Terakhir Dicek:',
                  (_bgDiagnostics?['lastPollTime'] != null &&
                          (_bgDiagnostics!['lastPollTime'] as num) > 0)
                      ? Formatters.formatDateTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            (_bgDiagnostics!['lastPollTime'] as num).toInt(),
                          ).toIso8601String(),
                        )
                      : 'Belum pernah polling',
                ),
                const SizedBox(height: 8),
                _buildDiagnosticRow(
                  'Status Polling:',
                  _bgDiagnostics?['lastPollStatus']?.toString() ??
                      'Menunggu siklus polling...',
                  isHighlight: true,
                ),
                const SizedBox(height: 8),
                _buildDiagnosticRow(
                  'Anti-Freeze Baterai:',
                  _bgDiagnostics?['isBatteryOptimizationIgnored'] == true
                      ? 'Diizinkan (Aman)'
                      : 'Belum Diizinkan',
                  statusColor: _bgDiagnostics?['isBatteryOptimizationIgnored'] == true
                      ? AppTheme.statusTeal
                      : AppTheme.statusDown,
                ),
                const SizedBox(height: 8),
                _buildDiagnosticRow(
                  'Layar Panggilan Darurat:',
                  _bgDiagnostics?['canUseFullScreenIntent'] == true
                      ? 'Diizinkan (Full-Screen)'
                      : 'Standar Notifikasi',
                  statusColor: _bgDiagnostics?['canUseFullScreenIntent'] == true
                      ? AppTheme.statusTeal
                      : AppTheme.statusWarning,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusTeal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.statusTeal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.statusTeal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'HP Realme / Oppo / Xiaomi / Vivo memerlukan izin "Mulai Otomatis" dan "Gembok Aplikasi" di Recent Apps agar notifikasi tidak terputus saat aplikasi di-close.',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => NotificationService().openAutoStartSettings(),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                    label: const Text(
                      'BUKA PENGATURAN MULAI OTOMATIS HP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.statusTeal,
                      side: BorderSide(
                        color: AppTheme.statusTeal.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService().testEmergencyCall();
                            if (context.mounted) {
                              AppFeedback.showSnackBar(
                                context,
                                message: 'Uji coba panggilan darurat dipicu.',
                              );
                            }
                          },
                          icon: const Icon(Icons.ring_volume_rounded, size: 16),
                          label: const Text(
                            'TES PANGGILAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.statusDown,
                            side: BorderSide(
                              color: AppTheme.statusDown.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService().testStandardAlert();
                            if (context.mounted) {
                              AppFeedback.showSnackBar(
                                context,
                                message: 'Uji coba notifikasi gangguan dikirim.',
                              );
                            }
                          },
                          icon: const Icon(Icons.notification_important_rounded, size: 16),
                          label: const Text(
                            'TES NOTIFIKASI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.statusWarning,
                            side: BorderSide(
                              color: AppTheme.statusWarning.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, authVm),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'KELUAR SISTEM',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.statusDown,
              backgroundColor: AppTheme.statusDown.withValues(alpha: 0.05),
              side: BorderSide(color: AppTheme.statusDown.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDiagnosticRow(
    String label,
    String value, {
    Color? statusColor,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: statusColor ?? (isHighlight ? AppTheme.statusTeal : _textMain),
              fontSize: 12,
              fontWeight: isHighlight || statusColor != null
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}