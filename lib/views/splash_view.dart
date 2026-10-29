import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  // Adaptive Theme Colors
  static Color get _bgMain => AppTheme.bgMain;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textMuted => AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: _bgMain,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              // Trik UI: Menggunakan bayangan persis mengikuti bentuk teks logo
              // agar teks putih di logo tetap terbaca di background putih
              Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Bayangan (Glow Gelap)
                  Transform.translate(
                    offset: const Offset(0, 2),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                      child: Image.asset(
                        'assets/diskominfosubang.png',
                        width: 210,
                        fit: BoxFit.contain,
                        // Warnai duplikat logo ini menjadi hitam transparan
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  
                  // Layer 2: Logo Utama
                  Image.asset(
                    'assets/diskominfosubang.png',
                    width: 210,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              
              const SizedBox(height: 16), // Jarak disesuaikan
              Text(
                'MONITORING & INCIDENT RESPONSE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.statusTeal,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}