// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// Memicu unduhan browser tanpa meninggalkan halaman aplikasi.
///
/// Byte berasal dari endpoint backend yang sudah memverifikasi JWT dan
/// kepemilikan data; tidak ada token yang ditempel ke URL.
Future<void> downloadFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Beri browser waktu memulai unduhan sebelum URL blob dilepas.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  html.Url.revokeObjectUrl(url);
}
