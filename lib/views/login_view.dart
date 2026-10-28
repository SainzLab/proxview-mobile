import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'common_widgets.dart';

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

  // Light Theme Colors
  static const Color _bgMain = Color(0xFFF8F9FA); // slate-50
  static const Color _bgCard = Colors.white;
  static const Color _borderSubtle = Color(0xFFE2E8F0); // slate-200
  static const Color _textMain = Color(0xFF0F172A); // slate-900
  static const Color _textSecondary = Color(0xFF475569); // slate-600
  static const Color _textMuted = Color(0xFF64748B); // slate-500
  static const Color _primaryAccent = Color(0xFF10B981); // emerald-500
  static const Color _textHint = Color(0xFF94A3B8);

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

    final authVm = context.read<AuthViewModel>();
    final ok = await authVm.login(
      serverUrl: serverUrl,
      username: username,
      password: password,
      token: token,
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
                  children: [
                    // Optional Logo Box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.insights_rounded,
                          color: _primaryAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ProxView',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'MONITORING PROXMOX & JARINGAN',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Error Message Box
                if (authVm.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2), // rose-50
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFECDD3), // rose-200
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFE11D48), // rose-600
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authVm.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFBE123C), // rose-700
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          Icon(
                            Icons.verified_user_outlined,
                            color: _primaryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
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
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Masukkan password akun',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
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
                        ),
                      ],

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: authVm.isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textMain, // slate-900 for Light Theme primary buttons
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFF1F5F9), // slate-100
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
                                    color: Colors.white, // Keep loader visible on dark button
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