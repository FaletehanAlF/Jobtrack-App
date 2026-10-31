import 'package:flutter/material.dart';

/// Palet warna bersama untuk seluruh halaman JobTrack.
///
/// Identitas utama JobTrack: navy `#0F2137` dan aksen biru `#1F6FEB`
/// (seed tema global serta komponen dashboard dan autentikasi).
/// Halaman onboarding/login/register memakai latar gradien lembut
/// (`authBackgroundTop` → `authBackgroundBottom`) dengan kolom form tanpa
/// kartu agar tampil ringan dan fokus pada isian.
class JobTrackColors {
  /// Teks utama dan ikon gelap.
  static const Color navy = Color(0xFF0F2137);

  /// Teks sekunder: subjudul, keterangan, ikon field.
  static const Color navyMuted = Color(0xFF5A6B7B);

  /// Aksen utama JobTrack: tombol, tautan, border field saat fokus, dan
  /// seed tema global (`MaterialApp`).
  static const Color blue = Color(0xFF1F6FEB);

  /// Latar lembut untuk elemen beraksen biru.
  static const Color blueSoft = Color(0xFFEAF2FF);

  /// Latar halaman.
  static const Color background = Color(0xFFF7F9FB);

  /// Latar kartu, field, dan tombol sosial.
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

  // ── Permukaan halaman autentikasi ──────────────────────────────────

  /// Gradien latar halaman autentikasi (atas → bawah).
  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [authBackgroundTop, authBackgroundBottom],
  );

  /// Warna puncak [authGradient].
  static const Color authBackgroundTop = Color(0xFFEEF3F9);

  /// Warna dasar [authGradient].
  static const Color authBackgroundBottom = Color(0xFFE3EBF5);

  /// Border field, pembatas, dan tombol sosial.
  static const Color authBorder = Color(0xFFD9E1EA);

  /// Latar lingkaran avatar di halaman autentikasi.
  static const Color authAvatarBackground = Color(0xFFF1F5FA);
}

/// Radius sudut yang dipakai bersama di seluruh halaman JobTrack.
class JobTrackRadii {
  /// Radius sudut field input.
  static const double field = 12;

  /// Radius sudut tombol utama (pill).
  static const double button = 28;

  /// Radius sudut kotak pesan.
  static const double banner = 14;

  /// Radius sudut tombol sosial (pill).
  static const double social = 28;
}
