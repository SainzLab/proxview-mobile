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
    final alertVm = context.watch<AlertIncidentViewModel>();
    final severityColor = AppTheme.severityColor(alert.severity);

    return Material(
      color: const Color(0xFF140202),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            children: [
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
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: severityColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: severityColor.withValues(alpha: 0.35),
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
              StatusBadge(label: '${alert.severity} • ${alert.targetType}'),
              const SizedBox(height: 16),
              Text(
                alert.targetName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  alert.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: alertVm.isSubmittingAction
                            ? null
                            : () => alertVm.dismissEmergencyCall(),
                        icon: const Icon(Icons.call_end_rounded),
                        label: const Text('TUTUP ALARM'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success
                                          ? Colors.teal
                                          : AppTheme.statusDown,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.build_circle_outlined),
                        label: const Text(
                          'TANGANI (JOIN)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.statusTeal,
                          foregroundColor: Colors.black,
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
