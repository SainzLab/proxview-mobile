import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'common_widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _obscurePassword = true;
  bool _showServerConfig = false;

  // Adaptive Theme Colors
  static Color get _bgMain => AppTheme.bgMain;
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;
  static const Color _primaryAccent = Color(0xFF10B981); // emerald-500
  static Color get _textHint => AppTheme.textHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      _serverUrlController.text = authVm.baseUrl;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  static final RegExp _hexTokenPattern = RegExp(r'^[a-fA-F0-9]{32,128}$');
  static final RegExp _usernamePattern = RegExp(r'^\S{2,64}$');

  Future<void> _submitLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final token = _tokenController.text.trim();
    final serverUrl = _serverUrlController.text.trim();

    if (username.isEmpty || password.isEmpty || token.isEmpty) {
      AppFeedback.showSnackBar(
        context,
        message: 'Username, Password, dan API Token (64-hex) wajib diisi.',
        isWarning: true,
      );
      return;
    }

    if (!_usernamePattern.hasMatch(username)) {
      AppFeedback.showSnackBar(
        context,
        message: 'Username harus terdiri dari 2–64 karakter tanpa spasi.',
        isWarning: true,
      );
      return;
    }

    if (!_hexTokenPattern.hasMatch(token)) {
      AppFeedback.showSnackBar(
        context,
        message: 'Format API Token tidak valid. Gunakan token heksadesimal dari Web Admin.',
        isWarning: true,
      );
      return;
    }

    if (serverUrl.isNotEmpty && !StorageService.isValidServerUrl(serverUrl)) {
      setState(() => _showServerConfig = true);
      AppFeedback.showSnackBar(
        context,
        message: 'Format Base URL Server tidak valid. Contoh: https://domain-anda.com atau http://192.168.1.10:7060',
        isWarning: true,
      );
      return;
    }

    // --- [MULAI BLOK TAMBAHAN FCM] ---
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("Berhasil mendapatkan FCM Token: $fcmToken");
    } catch (e) {
      // Gagal ambil FCM (misal di emulator tanpa Google Play), tetap biarkan login jalan
      debugPrint("Gagal mengambil FCM Token: $e");
    }
    // --- [SELESAI BLOK TAMBAHAN FCM] ---

    final authVm = context.read<AuthViewModel>();
    
    // Pastikan fungsi login di AuthViewModel sudah menerima parameter fcmToken
    final ok = await authVm.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
      token: token,
      fcmToken: fcmToken, // <-- Sisipkan fcmToken ke ViewModel
    );

    if (!ok && mounted && authVm.errorMessage != null) {
      AppFeedback.showSnackBar(
        context,
        message: authVm.errorMessage!,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    final themeVm = context.watch<ThemeViewModel>();
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: _bgMain,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trik UI: Drop Shadow Logo agar teks putih terbaca di light mode
                    RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Layer 1: Shadow (Glow Gelap) - Ukuran harus SAMA PERSIS dengan logo asli
                          Transform.translate(
                            offset: const Offset(0, 1.5),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                              child: Image.asset(
                                'assets/diskominfosubang.png',
                                height: 64, // FIXED: Disamakan dengan tinggi asli
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          // Layer 2: Original Logo
                          Image.asset(
                            'assets/diskominfosubang.png',
                            height: 64, // FIXED: Disamakan dengan bayangan
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => themeVm.toggleTheme(),
                      tooltip: themeVm.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                      icon: Icon(
                        themeVm.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: themeVm.isDarkMode ? AppTheme.statusWarning : _textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'PROX VIEW MONITORING PROXMOX',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message Box (Pemberitahuan ramah pengguna + Kode Error)
                if (authVm.errorMessage != null) ...[
                  Builder(
                    builder: (context) {
                      final parsed = ApiException.parse(authVm.errorMessage!);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.statusDown.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.statusDown.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.statusDown.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: AppTheme.statusDown,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          parsed.title,
                                          style: const TextStyle(
                                            color: AppTheme.statusDown,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (parsed.code != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.statusDown
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: AppTheme.statusDown
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            parsed.code!,
                                            style: const TextStyle(
                                              color: AppTheme.statusDown,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'monospace',
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    parsed.message,
                                    style: TextStyle(
                                      color: AppTheme.isDark
                                          ? _textSecondary
                                          : AppTheme.statusDown.withValues(alpha: 0.9),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => authVm.clearError(),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppTheme.statusDown.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Main Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: _primaryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'OTENTIKASI 3-FAKTOR',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      CustomTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Contoh: Asep_NOC',
                        icon: Icons.person_outline_rounded,
                        maxLength: 64,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Masukkan password akun',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        maxLength: 128,
                        autocorrect: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: _textHint,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        controller: _tokenController,
                        label: 'API Token',
                        hint: 'hex token dari Web Admin',
                        icon: Icons.vpn_key_outlined,
                        maxLength: 128,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 18),

                      InkWell(
                        onTap: () => setState(() => _showServerConfig = !_showServerConfig),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showServerConfig
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: _primaryAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Konfigurasi Endpoint Server',
                                style: TextStyle(
                                  color: _primaryAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showServerConfig) ...[
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _serverUrlController,
                          label: 'Base URL Server API',
                          hint: 'http(s)://ip-domain-atau-localhost:port',
                          icon: Icons.dns_outlined,
                          keyboardType: TextInputType.url,
                          maxLength: 256,
                          autocorrect: false,
                        ),
                      ],

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: authVm.isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.isDark ? _primaryAccent : _textMain,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.bgSurface,
                            disabledForegroundColor: _textHint,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: authVm.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'HUBUNGKAN PERANGKAT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}