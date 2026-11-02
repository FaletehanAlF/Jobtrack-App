import 'dart:typed_data';

/// Batas ukuran CV sama dengan validasi backend (5 MB).
const int cvMaxFileSizeBytes = 5 * 1024 * 1024;

/// File CV yang dipilih pengguna di Flutter Web.
class PickedCvFile {
  final String name;
  final Uint8List bytes;

  const PickedCvFile({required this.name, required this.bytes});

  int get size => bytes.length;
}
