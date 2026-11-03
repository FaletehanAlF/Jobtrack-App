import 'dart:typed_data';

const int cvMaxFileSizeBytes = 5 * 1024 * 1024;

class PickedCvFile {
  final String name;
  final Uint8List bytes;

  const PickedCvFile({required this.name, required this.bytes});

  int get size => bytes.length;
}
