import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import 'common_widgets.dart';

class PdfExportButton extends StatelessWidget {
  final PdfReportType initialType;
  final String initialPeriod;
  final String initialSeverity;
  final String initialTimeframe;
  final String label;
  final bool compact;

  const PdfExportButton({
    super.key,
    required this.initialType,
    this.initialPeriod = '24h',
    this.initialSeverity = 'ALL',
    this.initialTimeframe = '1h',
    this.label = 'Export PDF',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PdfExportSheet.show(
          context,
          initialType: initialType,
          initialPeriod: initialPeriod,
          initialSeverity: initialSeverity,
          initialTimeframe: initialTimeframe,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.statusTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.statusTeal.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: compact ? 14 : 15,
                color: AppTheme.statusTeal,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.statusTeal,
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PdfExportSheet extends StatefulWidget {
  final PdfReportType initialType;
  final String initialPeriod;
  final String initialSeverity;
  final String initialTimeframe;

  const PdfExportSheet({
    super.key,
    required this.initialType,
    this.initialPeriod = '24h',
    this.initialSeverity = 'ALL',
    this.initialTimeframe = '1h',
  });

  static Future<void> show(
    BuildContext context, {
    required PdfReportType initialType,
    String initialPeriod = '24h',
    String initialSeverity = 'ALL',
    String initialTimeframe = '1h',
  }) {
    final normalizedSeverity = const {'ALL', 'DOWN', 'CRITICAL', 'WARNING'}
            .contains(initialSeverity.toUpperCase())
        ? initialSeverity.toUpperCase()
        : 'ALL';
    final normalizedPeriod =
        const {'24h', '7d', '30d'}.contains(initialPeriod) ? initialPeriod : '24h';
    final normalizedTimeframe = const {'1h', '24h', '7d'}.contains(initialTimeframe)
        ? initialTimeframe
        : '1h';

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PdfExportSheet(
        initialType: initialType,
        initialPeriod: normalizedPeriod,
        initialSeverity: normalizedSeverity,
        initialTimeframe: normalizedTimeframe,
      ),
    );
  }

  @override
  State<PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<PdfExportSheet> {
  late PdfReportType _reportType;
  late String _period;
  late String _severity;
  late String _timeframe;

  bool _isDownloading = false;
  double? _progress;
  int _receivedBytes = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _reportType = widget.initialType;
    _period = widget.initialPeriod;
    _severity = widget.initialSeverity;
    _timeframe = widget.initialTimeframe;
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Sheet ditutup');
    super.dispose();
  }

  Future<void> _startDownload({required bool shareInstead}) async {
    if (_isDownloading) return;

    final pdfService = context.read<PdfExportService>();
    final token = CancelToken();

    setState(() {
      _isDownloading = true;
      _progress = null;
      _receivedBytes = 0;
      _cancelToken = token;
    });

    try {
      void onProgress(int received, int total) {
        if (!mounted) return;
        setState(() {
          _receivedBytes = received;
          _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
        });
      }

      final result = _reportType == PdfReportType.incidents
          ? await pdfService.downloadIncidentsPdf(
              period: _period,
              severity: _severity,
              autoOpen: !shareInstead,
              shareInstead: shareInstead,
              onProgress: onProgress,
              cancelToken: token,
            )
          : await pdfService.downloadDashboardPdf(
              timeframe: _timeframe,
              period: _period,
              severity: _severity,
              autoOpen: !shareInstead,
              shareInstead: shareInstead,
              onProgress: onProgress,
              cancelToken: token,
            );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSnackBar(
        context,
        message: result.statusMessage,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isCancelled) {
        setState(() {
          _isDownloading = false;
        });
        return;
      }
      setState(() {
        _isDownloading = false;
      });
      AppFeedback.showSnackBar(
        context,
        message: e.toString(),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      AppFeedback.showSnackBar(
        context,
        message: 'Gagal mengunduh laporan PDF: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return SafeArea(
      top: false,
      child: BottomSheetContainer(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.statusTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderColor),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppTheme.statusTeal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unduh Laporan PDF',
                          style: TextStyle(
                            color: colors.textMain,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih jenis dokumen resmi dan parameter periode laporan.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'JENIS LAPORAN',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              _buildReportTypeTile(
                colors: colors,
                type: PdfReportType.incidents,
                icon: Icons.assignment_late_outlined,
              ),
              const SizedBox(height: 18),
              Text(
                'RENTANG WAKTU ANALITIK SLA (PERIOD)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              _buildOptionRow(
                colors: colors,
                options: const [
                  ('24h', '24 Jam'),
                  ('7d', '7 Hari'),
                  ('30d', '30 Hari'),
                ],
                selected: _period,
                onSelect: (val) => setState(() => _period = val),
              ),
              const SizedBox(height: 16),
              Text(
                'FILTER TINGKAT KEPARAHAN (SEVERITY)',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              _buildOptionRow(
                colors: colors,
                options: const [
                  ('ALL', 'Semua'),
                  ('DOWN', 'Down'),
                  ('CRITICAL', 'Critical'),
                  ('WARNING', 'Warning'),
                ],
                selected: _severity,
                onSelect: (val) => setState(() => _severity = val),
              ),
              if (_isDownloading) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Menyiapkan & mengunduh PDF...',
                            style: TextStyle(
                              color: colors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _progress != null
                                ? '${(_progress! * 100).toStringAsFixed(0)}%'
                                : (_receivedBytes > 0
                                    ? '${(_receivedBytes / 1024).toStringAsFixed(0)} KB'
                                    : '...'),
                            style: const TextStyle(
                              color: AppTheme.statusTeal,
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 5,
                          backgroundColor: colors.bgCard,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.statusTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (_isDownloading)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelToken?.cancel('Dibatalkan pengguna'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'BATALKAN UNDUHAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.statusDown,
                      side: BorderSide(
                        color: AppTheme.statusDown.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _startDownload(shareInstead: true),
                      icon: const Icon(Icons.share_outlined, size: 17),
                      label: const Text(
                        'BAGIKAN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.borderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _startDownload(shareInstead: false),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'UNDUH & BUKA PDF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.statusTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  Widget _buildReportTypeTile({
    required ProxViewThemeColors colors,
    required PdfReportType type,
    required IconData icon,
  }) {
    final isSelected = _reportType == type;
    return InkWell(
      onTap: _isDownloading ? null : () => setState(() => _reportType = type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.statusTeal.withValues(alpha: 0.1)
              : colors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.statusTeal.withValues(alpha: 0.45)
                : colors.borderColor,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.statusTeal : colors.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: TextStyle(
                      color: colors.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.subtitle,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              size: 19,
              color: isSelected ? AppTheme.statusTeal : colors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required ProxViewThemeColors colors,
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSel = selected == opt.$1;
        return InkWell(
          onTap: _isDownloading ? null : () => onSelect(opt.$1),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? AppTheme.statusTeal.withValues(alpha: 0.12)
                  : colors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel
                    ? AppTheme.statusTeal.withValues(alpha: 0.45)
                    : colors.borderColor,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                color: isSel ? AppTheme.statusTeal : colors.textSecondary,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}