import '../models/cv_file.dart';

/// Picker file hanya tersedia di Flutter Web. Platform lain mengembalikan null
/// sehingga formulir tetap bisa dipakai untuk melamar tanpa CV.
Future<PickedCvFile?> pickCvFile() async => null;
