import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'common_widgets.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.statusTeal.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const CustomPaint(
                size: Size(42, 28),
                painter: PulseLogoPainter(
                  color: AppTheme.statusTeal,
                  strokeWidth: 3.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ProxView',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'MONITORING & INCIDENT RESPONSE',
              style: TextStyle(
                color: Colors.white54,
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
    );
  }
}
