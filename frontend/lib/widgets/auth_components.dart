import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

/// Kerangka halaman autentikasi (onboarding, login, register).
///
/// Tanggung jawabnya hanya tata letak, bukan isi:
/// - konten selalu terpusat dengan lebar maksimum [maxContentWidth], jadi di
///   layar web/desktop form tidak melebar memenuhi layar;
/// - pada layar lebar konten dibungkus kartu putih; pada ponsel tampil datar
///   di atas latar halaman, sehingga tampilan Android tidak berubah drastis;
/// - halaman bisa digulir bila tinggi layar terbatas atau keyboard ponsel
///   muncul (Scaffold menyusutkan body saat keyboard tampil).
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.showBackButton = true,
  });

  final Widget child;

  /// Login dan register dibuka lewat Navigator sehingga butuh tombol kembali.
  /// Onboarding adalah halaman akar, jadi tidak memakainya.
  final bool showBackButton;

  /// Lebar maksimum konten. Di atas angka ini konten tetap terpusat.
  static const double maxContentWidth = 440;

  /// Ambang lebar untuk tampilan kartu di layar besar.
  static const double _cardBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: const IconThemeData(color: JobTrackColors.navy),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _cardBreakpoint;
            // Ponsel sangat sempit (mis. 320 dp) memakai padding lebih kecil
            // agar isi field tidak terasa terjepit.
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 28.0;

            // Konten: di layar lebar dibungkus kartu, di ponsel dibiarkan
            // datar. Padding vertikal hanya dipakai versi datar karena kartu
            // sudah punya padding sendiri.
            final content = isWide
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: JobTrackColors.surface,
                      borderRadius: BorderRadius.circular(JobTrackRadii.card),
                      border: Border.all(color: JobTrackColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F2137),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: child,
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: child,
                  );

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Judul halaman autentikasi: logo, judul, dan subjudul terpusat.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.logoSize = 72,
  });

  final String title;
  final String? subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: JobTrackLogo(size: logoSize)),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitleText != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitleText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Logo JobTrack: gambar bulat dengan latar putih.
///
/// Memakai `jobtrack.png` karena format PNG didukung semua target: Android,
/// iOS, desktop, dan Flutter Web. (Versi AVIF dulu sempat dipakai, tetapi
/// sebagian perangkat Android dan browser gagal men-decode-nya — terlihat
/// dari log `HeifDecoderImpl ... videoFrame is a nullptr` — jadi AVIF
/// dibuang dan file aslinya diarsipkan di luar proyek.)
///
/// Bila gambar gagal dimuat — misalnya file tidak ikut ter-bundle —
/// widget menampilkan monogram "JT" agar halaman tidak error.
class JobTrackLogo extends StatelessWidget {
  const JobTrackLogo({super.key, this.size = 88});

  final double size;

  static const String assetPath = 'assets/image/jobtrack.png';

  /// Tampilan cadangan: monogram "JT" dengan skala mengikuti [size].
  Widget _monogram() {
    return Center(
      child: Text(
        'JT',
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: JobTrackColors.navy,
          letterSpacing: -1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: JobTrackColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x140F2137),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Padding kecil memberi ruang antara konten PNG dan tepi lingkaran.
      // Tanpa ini, gambar yang isinya menyentuh tepi kanvas terlihat
      // "kepotong" menempel pada border lingkaran.
      padding: EdgeInsets.all(size * 0.08),
      child: Image.asset(
        assetPath,
        // Gambar memenuhi lingkaran putih; file PNG-nya sendiri sudah
        // dipangkas agar kontennya pas di tengah kanvas.
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _monogram(),
      ),
    );
  }
}

/// Tombol utama: biru solid, lebar penuh, tinggi 52 (nyaman disentuh).
///
/// Saat [loading] tombol dinonaktifkan dan menampilkan indikator berputar,
/// sehingga request tidak terkirim dua kali.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: JobTrackColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: JobTrackColors.disabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JobTrackRadii.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Baris tautan di bawah form, mis. "Belum punya akun? Daftar".
///
/// Memakai [Wrap] agar tetap rapi di layar sempit saat teks pertanyaan
/// panjang — [Row] biasa akan overflow di sana.
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.question,
    required this.action,
    this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            color: JobTrackColors.navyMuted,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: JobTrackColors.blue,
            disabledForegroundColor: JobTrackColors.disabled,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Kotak pesan gagal di atas tombol submit.
///
/// Dipilih daripada SnackBar karena pesannya tetap terlihat selama pengguna
/// memperbaiki isian, tidak hilang setelah beberapa detik.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JobTrackColors.dangerSoft,
        borderRadius: BorderRadius.circular(JobTrackRadii.banner),
        border: Border.all(color: JobTrackColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: JobTrackColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: JobTrackColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gaya seragam untuk semua field di form autentikasi.
///
/// Ditaruh di satu fungsi supaya border, padding, dan warna fokus tidak
/// berbeda antar halaman. Warna error mengikuti [JobTrackColors.danger]
/// agar pesan validasi mudah dibedakan dari teks biasa.
InputDecoration authFieldDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final radius = BorderRadius.circular(JobTrackRadii.field);
  final restingBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: const BorderSide(color: JobTrackColors.border, width: 1.2),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: JobTrackColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: restingBorder,
    enabledBorder: restingBorder,
    disabledBorder: restingBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: JobTrackColors.blue, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: JobTrackColors.danger, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: JobTrackColors.danger, width: 1.6),
    ),
    labelStyle: const TextStyle(fontSize: 15, color: JobTrackColors.navyMuted),
    floatingLabelStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: JobTrackColors.blue,
    ),
    hintStyle: const TextStyle(fontSize: 15, color: JobTrackColors.hint),
    errorStyle: const TextStyle(fontSize: 12.5, color: JobTrackColors.danger),
    errorMaxLines: 2,
  );
}

/// Ikon di dalam field, dengan warna dan ukuran yang konsisten.
class AuthFieldIcon extends StatelessWidget {
  const AuthFieldIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 22, color: JobTrackColors.navyMuted);
  }
}
