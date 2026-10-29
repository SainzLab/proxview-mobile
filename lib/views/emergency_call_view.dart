import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/alert_incident_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import 'common_widgets.dart';

class EmergencyCallView extends StatelessWidget {
  final AlertModel alert;

  const EmergencyCallView({super.key, required this.alert});

  // Adaptive Theme Colors
  static Color get _bgMain => AppTheme.bgCard;
  static Color get _bgSurface => AppTheme.bgSurface;
  static Color get _borderSubtle => AppTheme.borderColor;
  static Color get _textMain => AppTheme.textMain;
  static Color get _textSecondary => AppTheme.textSecondary;
  static Color get _textMuted => AppTheme.textMuted;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final alertVm = context.watch<AlertIncidentViewModel>();
    final severityColor = AppTheme.severityColor(alert.severity);

    return Scaffold(
      backgroundColor: _bgMain,
      body: Stack(
        children: [
          // Efek Ambient Glow Merah (Halus) di latar belakang
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.statusDown.withValues(alpha: 0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.ring_volume_rounded,
                        color: AppTheme.statusDown,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PANGGILAN DARURAT INSIDEN (${alert.actionType.toUpperCase()})',
                        style: const TextStyle(
                          color: AppTheme.statusDown,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Center Pulse Icon
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: severityColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: severityColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: severityColor.withValues(alpha: 0.15),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      AppTheme.severityIcon(alert.severity),
                      size: 64,
                      color: severityColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  StatusBadge(
                    label: '${alert.severity} • ${alert.targetType}',
                    color: severityColor,
                    showDot: false,
                  ),
                  const SizedBox(height: 16),
                  
                  // Target Name
                  Text(
                    alert.targetName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Message Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderSubtle),
                    ),
                    child: Text(
                      alert.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: alertVm.isSubmittingAction
                                ? null
                                : () async {
                                    final confirmed = await AppFeedback.showConfirmDialog(
                                      context,
                                      title: 'Tutup Panggilan Darurat?',
                                      message:
                                          'Alarm darurat untuk "${alert.targetName}" akan ditutup pada perangkat Anda, namun status insiden tetap aktif.',
                                      confirmLabel: 'TUTUP ALARM',
                                      accentColor: AppTheme.statusDown,
                                      icon: Icons.call_end_rounded,
                                    );
                                    if (confirmed) {
                                      alertVm.dismissEmergencyCall();
                                    }
                                  },
                            icon: const Icon(Icons.call_end_rounded, size: 18),
                            label: const Text(
                              'TUTUP ALARM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textMuted,
                              side: BorderSide(color: _borderSubtle),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: alertVm.isSubmittingAction
                                ? null
                                : () async {
                                    final res = await alertVm.joinAlert(alert.id);
                                    if (context.mounted) {
                                      AppFeedback.showSnackBar(
                                        context,
                                        message: res.message,
                                        isError: !res.success,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.handyman_rounded, size: 18),
                            label: const Text(
                              'TANGANI',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.statusTeal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              shadowColor: AppTheme.statusTeal.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}