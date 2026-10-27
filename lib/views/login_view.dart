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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ProxView',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'MONITORING PROXMOX & JARINGAN',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                if (authVm.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.statusDown.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.statusDown.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.statusDown,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authVm.errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'OTENTIKASI 3-FAKTOR',
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Contoh: Asep_NOC',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Masukkan password akun',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _tokenController,
                        label: 'API Token',
                        hint: 'hex token dari Web Admin',
                        icon: Icons.vpn_key_outlined,
                      ),
                      const SizedBox(height: 16),

                      InkWell(
                        onTap: () => setState(() => _showServerConfig = !_showServerConfig),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _showServerConfig
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.statusTeal,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Konfigurasi Endpoint Server',
                                style: TextStyle(
                                  color: AppTheme.statusTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showServerConfig) ...[
                        const SizedBox(height: 10),
                        CustomTextField(
                          controller: _serverUrlController,
                          label: 'Base URL Server API',
                          hint: 'http(s)://ip-domain-atau-localhost:port',
                          icon: Icons.dns_outlined,
                          keyboardType: TextInputType.url,
                        ),
                      ],

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: authVm.isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.statusTeal,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white12,
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
                                    color: Colors.black,
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
                                        letterSpacing: 1.2,
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
