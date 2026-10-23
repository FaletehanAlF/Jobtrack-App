import 'package:flutter/material.dart';

/// Palet warna bersama untuk seluruh halaman JobTrack.
///
/// Nilainya sama dengan palet yang sudah dipakai halaman lain
/// (navy `#0F2137`, aksen biru `#1F6FEB`, latar `#F7F9FB`). Token tambahan
/// (border, danger) hanya melengkapi palet lama, bukan menggantikannya,
/// supaya halaman yang belum disentuh tetap tampil sama.
class JobTrackColors {
  /// Teks utama dan ikon gelap.
  static const Color navy = Color(0xFF0F2137);

  /// Teks sekunder: subjudul, keterangan, ikon field.
  static const Color navyMuted = Color(0xFF5A6B7B);

  /// Aksen utama: tombol utama, tautan, dan border field saat fokus.
  static const Color blue = Color(0xFF1F6FEB);

  /// Latar lembut untuk elemen beraksen biru.
  static const Color blueSoft = Color(0xFFEAF2FF);

  /// Latar halaman.
  static const Color background = Color(0xFFF7F9FB);

  /// Latar kartu dan field.
  static const Color surface = Color(0xFFFFFFFF);

  /// Garis pemisah dan border field dalam keadaan diam.
  static const Color border = Color(0xFFE2E8F0);

  /// Border yang sedikit lebih tegas (tombol sekunder).
  static const Color borderStrong = Color(0xFFD3DCE6);

  /// Teks dan ikon pesan gagal.
  static const Color danger = Color(0xFFB42318);

  /// Latar pesan gagal.
  static const Color dangerSoft = Color(0xFFFDECEA);

  /// Border pesan gagal.
  static const Color dangerBorder = Color(0xFFF3C6C1);

  /// Placeholder di dalam field.
  static const Color hint = Color(0xFF9AA7B4);

  /// Warna tombol utama saat dinonaktifkan (mis. sedang loading).
  static const Color disabled = Color(0xFFB9C6D3);
}

/// Radius sudut yang dipakai bersama oleh form autentikasi.
class JobTrackRadii {
  static const double field = 14;
  static const double button = 14;
  static const double banner = 12;
  static const double card = 24;
}
