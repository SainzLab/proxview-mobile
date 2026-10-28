import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'common_widgets.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _baseUrlController = TextEditingController();

  // Light Theme Specific Colors
  static const Color _bgCard = Colors.white;
  static const Color _borderSubtle = Color(0xFFE2E8F0); // slate-200
  static const Color _textMain = Color(0xFF0F172A); // slate-900
  static const Color _textSecondary = Color(0xFF475569); // slate-600
  static const Color _textMuted = Color(0xFF64748B); // slate-500
  static const Color _textHint = Color(0xFF94A3B8); // slate-400

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      _baseUrlController.text = authVm.baseUrl;
    });
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

    final confirmed = await AppFeedback.showConfirmDialog(
      context,
      title: 'Simpan Konfigurasi Server?',
      message:
          'Endpoint API akan diperbarui ke "$trimmed". Pastikan alamat server dapat diakses oleh perangkat ini.',
      confirmLabel: 'SIMPAN',
      accentColor: AppTheme.statusTeal,
      icon: Icons.dns_rounded,
    );
    if (!confirmed || !mounted) return;

    final authVm = context.read<AuthViewModel>();
    await authVm.updateBaseUrl(trimmed);
    if (mounted) {
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
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(color: _textSecondary, fontSize: 12.5),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: _borderSubtle, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 15, color: _textHint),
                          SizedBox(width: 6),
                          Text(
                            'Batas Waktu Sesi:',
                            style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        Formatters.formatDateTime(user.tokenExpiresAt),
                        style: const TextStyle(
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
              const Text(
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
}