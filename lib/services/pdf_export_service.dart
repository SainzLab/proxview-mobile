import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_service.dart';

enum PdfReportType {
  incidents,
  dashboard;

  String get label {
    switch (this) {
      case PdfReportType.incidents:
        return 'Rekap Gangguan & SLA';
      case PdfReportType.dashboard:
        return 'Ringkasan Dashboard Infrastruktur';
    }
  }

  String get subtitle {
    switch (this) {
      case PdfReportType.incidents:
        return 'Daftar insiden, durasi gangguan, MTTR, MTBF & ketersediaan.';
      case PdfReportType.dashboard:
        return 'Cluster Proxmox, utilisasi resource.';
    }
  }
}

class PdfExportResult {
  final File file;
  final String fileName;
  final bool opened;
  final String statusMessage;

  const PdfExportResult({
    required this.file,
    required this.fileName,
    required this.opened,
    required this.statusMessage,
  });
}

class PdfExportService {
  final ProxViewApiService _apiService;

  const PdfExportService(this._apiService);

  /// Unduh PDF Rekap Gangguan & SLA (`/api/mobile/v1/export/pdf/incidents`)
  Future<PdfExportResult> downloadIncidentsPdf({
    String period = '24h',
    String severity = 'ALL',
    bool autoOpen = true,
    bool shareInstead = false,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final downloaded = await _apiService.downloadIncidentsPdfBytes(
      period: period,
      severity: severity,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    return _saveAndHandlePdf(
      bytes: downloaded.bytes,
      fileName: downloaded.fileName,
      autoOpen: autoOpen,
      shareInstead: shareInstead,
    );
  }

  /// Unduh PDF Ringkasan Dashboard Infrastruktur (`/api/mobile/v1/export/pdf/dashboard`)
  Future<PdfExportResult> downloadDashboardPdf({
    String timeframe = '1h',
    String period = '24h',
    String severity = 'ALL',
    bool autoOpen = true,
    bool shareInstead = false,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final downloaded = await _apiService.downloadDashboardPdfBytes(
      timeframe: timeframe,
      period: period,
      severity: severity,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    return _saveAndHandlePdf(
      bytes: downloaded.bytes,
      fileName: downloaded.fileName,
      autoOpen: autoOpen,
      shareInstead: shareInstead,
    );
  }

  Future<PdfExportResult> _saveAndHandlePdf({
    required Uint8List bytes,
    required String fileName,
    required bool autoOpen,
    required bool shareInstead,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (shareInstead) {
      await sharePdfFile(file, fileName: fileName);
      return PdfExportResult(
        file: file,
        fileName: fileName,
        opened: true,
        statusMessage: 'Laporan PDF siap dibagikan ($fileName).',
      );
    }

    if (autoOpen) {
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type == ResultType.done) {
        return PdfExportResult(
          file: file,
          fileName: fileName,
          opened: true,
          statusMessage: 'Laporan PDF berhasil diunduh dan dibuka ($fileName).',
        );
      }

      // Fallback ke OS Share Sheet apabila perangkat belum memiliki aplikasi pembaca PDF
      if (result.type == ResultType.noAppToOpen) {
        await sharePdfFile(file, fileName: fileName);
        return PdfExportResult(
          file: file,
          fileName: fileName,
          opened: false,
          statusMessage:
              'Tidak ditemukan aplikasi pembaca PDF bawaan. Membuka menu simpan/bagikan file.',
        );
      }

      return PdfExportResult(
        file: file,
        fileName: fileName,
        opened: false,
        statusMessage: 'PDF tersimpan ($fileName), namun gagal dibuka otomatis: ${result.message}',
      );
    }

    return PdfExportResult(
      file: file,
      fileName: fileName,
      opened: false,
      statusMessage: 'Laporan PDF berhasil disimpan ($fileName).',
    );
  }

  Future<void> sharePdfFile(File file, {String? fileName}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
        subject: fileName ?? 'Laporan ProxView PDF',
      ),
    );
  }
}
