/// Fallback non-web untuk menjaga test Flutter VM tetap dapat dikompilasi.
/// Aplikasi mobile tidak menjadi target fitur ekspor ini.
Future<void> downloadFileBytes({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('Unduhan file hanya tersedia pada Flutter Web.');
}
