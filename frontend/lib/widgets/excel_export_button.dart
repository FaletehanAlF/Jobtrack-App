import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/jobtrack_theme.dart';
import '../utils/file_download.dart';

typedef ReportDownloadHandler = Future<void> Function(ApiDownload file);

/// Tombol ekspor bersama untuk halaman jobseeker dan recruiter.
///
/// File selalu dibuat backend. Widget ini hanya menangani status loading,
/// pemanggilan unduhan browser, serta pesan berhasil/gagal.
class ExcelExportButton extends StatefulWidget {
  const ExcelExportButton({
    super.key,
    required this.onExport,
    this.enabled = true,
    this.downloadHandler,
    this.buttonKey,
    this.label = 'Ekspor Excel',
    this.successMessage = 'Laporan Excel berhasil diunduh.',
    this.disabledMessage = 'Tidak ada data untuk diekspor.',
  });

  final Future<ApiDownload> Function() onExport;
  final bool enabled;
  final ReportDownloadHandler? downloadHandler;
  final Key? buttonKey;
  final String label;
  final String successMessage;
  final String disabledMessage;

  @override
  State<ExcelExportButton> createState() => _ExcelExportButtonState();
}

class _ExcelExportButtonState extends State<ExcelExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    if (!widget.enabled || _exporting) return;

    setState(() => _exporting = true);

    try {
      final file = await widget.onExport();
      await (widget.downloadHandler ?? _downloadFile)(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor laporan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  static Future<void> _downloadFile(ApiDownload file) {
    return downloadFileBytes(
      fileName: file.fileName,
      bytes: file.bytes,
      mimeType: file.contentType,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unduhan .xlsx hanya untuk Flutter Web. Di build mobile tombol tidak
    // ditampilkan agar aplikasi mobile yang sudah ada tidak berubah. Handler
    // khusus tetap dipakai oleh widget test yang berjalan di Flutter VM.
    if (!kIsWeb && widget.downloadHandler == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: widget.enabled ? widget.label : widget.disabledMessage,
      child: OutlinedButton.icon(
        key: widget.buttonKey,
        onPressed: widget.enabled && !_exporting ? _export : null,
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(_exporting ? 'Menyiapkan...' : widget.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: JobTrackColors.blue,
          backgroundColor: JobTrackColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
