import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'common_widgets.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  // Adaptive Theme Colors
  static Color get _bgMain => AppTheme.bgMain;
  static Color get _bgCard => AppTheme.bgCard;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textMuted => AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: _bgMain,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.statusTeal.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.statusTeal.withValues(alpha: 0.12),
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
            Text(
              'ProxView',
              style: TextStyle(
                color: _textMain,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MONITORING & INCIDENT RESPONSE',
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
    );
  }
}