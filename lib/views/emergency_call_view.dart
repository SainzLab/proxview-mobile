import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/alert_incident_model.dart';
import '../viewmodels/alert_incident_viewmodel.dart';
import 'common_widgets.dart';

class EmergencyCallView extends StatelessWidget {
  final AlertModel alert;

  const EmergencyCallView({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final alertVm = context.watch<AlertIncidentViewModel>();
    final severityColor = AppTheme.severityColor(alert.severity);
    final cleanMessage = alert.message.trim().isNotEmpty
        ? alert.message.trim()
        : 'Terdeteksi gangguan kritis pada sistem.';

    return Scaffold(
      backgroundColor: colors.bgCard,
      body: SafeArea(
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
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PANGGILAN DARURAT INSIDEN',
                    style: TextStyle(
                      color: AppTheme.statusDown,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Center Icon Container (Border netral tanpa glow mencolok)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: severityColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: colors.borderColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: colors.isDark ? 0.2 : 0.05,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  AppTheme.severityIcon(alert.severity),
                  size: 56,
                  color: severityColor,
                ),
              ),
              const SizedBox(height: 24),

              // Badge Severity & Target Type (Border netral)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${alert.severity.toUpperCase()} • ${alert.targetType.toUpperCase()}',
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target Name
              Text(
                alert.targetName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMain,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),

              // Message Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderColor),
                ),
                child: Text(
                  cleanMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
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
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: alertVm.isSubmittingAction
                            ? null
                            : () async {
                                final confirmed =
                                    await AppFeedback.showConfirmDialog(
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
                          foregroundColor: colors.textMuted,
                          side: BorderSide(color: colors.borderColor),
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
                      height: 52,
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
    );
  }
}