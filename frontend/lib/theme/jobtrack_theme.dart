import 'package:flutter/material.dart';

/// Palet warna bersama untuk seluruh halaman JobTrack.
///
/// Identitas utama JobTrack: navy `#0F2137` dan aksen biru `#1F6FEB`
/// (seed tema global, dashboard, dan komponen autentikasi).
/// Halaman onboarding/login/register memakai latar gradien lembut serta
/// kartu putih (`authBackgroundTop`, `authBackgroundBottom`, `authCard`)
/// agar tampil ringan dan fokus pada form.
/// Token `warm*`/teal lama tetap tersimpan sebagai token opsional, tetapi
/// tidak lagi dipakai halaman autentikasi.
class JobTrackColors {
  /// Teks utama dan ikon gelap.
  static const Color navy = Color(0xFF0F2137);

  /// Teks sekunder: subjudul, keterangan, ikon field.
  static const Color navyMuted = Color(0xFF5A6B7B);

  /// Aksen utama JobTrack: tombol, tautan, border field saat fokus, dan
  /// seed tema global (`MaterialApp`) — dashboard maupun halaman autentikasi.
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

  // ── Permukaan halaman autentikasi ──────────────────────────────────

  /// Gradien latar halaman autentikasi (atas → bawah).
  static const Color authBackgroundTop = Color(0xFFEEF3F9);
  static const Color authBackgroundBottom = Color(0xFFE3EBF5);

  /// Kartu putih tempat form autentikasi.
  static const Color authCard = Color(0xFFFFFFFF);

  /// Border field, pembatas, dan tombol sosial.
  static const Color authBorder = Color(0xFFD9E1EA);

  /// Bayangan lembut kartu dan tombol utama.
  static const Color authShadow = Color(0x140F2137);

  /// Latar lingkaran avatar di halaman autentikasi.
  static const Color authAvatarBackground = Color(0xFFF1F5FA);

  // ── Token lama (tidak dipakai halaman autentikasi baru) ───────────

  /// Latar halaman hangat (krem/off-white) halaman autentikasi.
  static const Color warmBackground = Color(0xFFF5F0E8);

  /// Latar card form (putih hangat).
  static const Color warmSurface = Color(0xFFFFFCF7);

  /// Token teal/olive di bawah tidak dipakai halaman mana pun setelah
  /// halaman autentikasi kembali ke aksen biru/navy JobTrack.
  static const Color teal = Color(0xFF1B6B6B);

  /// (Tidak dipakai; sebelumnya warna header autentikasi, kini navy.)
  static const Color tealDark = Color(0xFF0F4F4F);

  /// Teal lembut untuk latar ikon dan aksen sekunder.
  static const Color tealSoft = Color(0xFFE0F0EE);

  /// Olive hijau untuk detail kecil (label, border aksen).
  static const Color olive = Color(0xFF6B7F5E);

  /// Border hangat untuk field dan card.
  static const Color warmBorder = Color(0xFFE5DFD4);

  /// Teks utama pada latar hangat.
  static const Color warmText = Color(0xFF1A2E2E);

  /// Teks sekunder pada latar hangat.
  static const Color warmTextMuted = Color(0xFF5A6B6B);
}

/// Radius sudut yang dipakai bersama oleh form autentikasi.
class JobTrackRadii {
  static const double field = 12;
  static const double button = 28;
  static const double banner = 14;
  static const double card = 32;
  static const double social = 28;
}
