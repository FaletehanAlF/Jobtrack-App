import 'package:flutter/material.dart';

class JobTrackColors {
  static const Color navy = Color(0xFF0F2137);
  static const Color navyMuted = Color(0xFF5A6B7B);
  static const Color blue = Color(0xFF1F6FEB);
  static const Color background = Color(0xFFF7F9FB);
  static const Color surface = Color(0xFFFFFFFF);
}

/// Halaman onboarding: layar pertama yang dilihat pengguna sebelum
/// masuk atau mendaftar.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onLogin, this.onSignUp});

  final VoidCallback? onLogin;
  final VoidCallback? onSignUp;

  // Lebar maksimum konten. Di tablet dan desktop konten tetap terpusat,
  // tidak melebar memenuhi seluruh layar.
  static const double _maxContentWidth = 440;

  // Tombol tetap terlihat aktif walau callback belum dipasang, supaya
  // tampilan onboarding tidak terlihat seperti aplikasi yang rusak.
  // Selama halaman login/register belum ada, ketukan hanya menampilkan
  // pemberitahuan singkat.
  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Halaman ini belum tersedia'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JobTrackColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Layar pendek (mis. ponsel miring) perlu scroll agar tombol
            // tidak terpotong. Layar tinggi memakai sisa ruang untuk
            // memberi jarak, bukan tinggi tetap.
            final isCompactHeight = constraints.maxHeight < 560;
            final horizontalPadding = constraints.maxWidth < 380 ? 20.0 : 28.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isCompactHeight ? 20 : 32,
                      ),
                      child: SizedBox(
                        // Memenuhi tinggi layar; dengan scroll, minHeight
                        // sudah ditetapkan lewat ConstrainedBox di atas.
                        width: double.infinity,
                        child: _content(context, isCompactHeight),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool isCompactHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(child: _JobTrackLogo(size: 88)),
        const SizedBox(height: 14),

        // Nama aplikasi, diletakkan tepat di bawah logo.
        const Text(
          'JobTrack',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: isCompactHeight ? 20 : 32),

        const Text(
          'Temukan Peluang Kariermu',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: JobTrackColors.navy,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Cari lowongan kerja yang sesuai dengan kemampuan dan tujuan kariermu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: JobTrackColors.navyMuted,
          ),
        ),

        // Sisa ruang kosong mendorong tombol ke bawah pada layar tinggi.
        // Pada layar pendek nilainya mengecil agar tidak memaksa scroll.
        SizedBox(height: isCompactHeight ? 32 : 72),

        _PrimaryButton(
          label: 'Masuk',
          onPressed: onLogin ?? () => _notReady(context),
        ),
        const SizedBox(height: 12),
        _SecondaryButton(
          label: 'Daftar',
          onPressed: onSignUp ?? () => _notReady(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Logo JobTrack: gambar bulat di tengah halaman.
///
/// Memakai `jobtrack.png` karena format PNG didukung semua target: Android,
/// iOS, desktop, dan Flutter Web. (Versi AVIF dulu sempat dipakai, tetapi
/// sebagian perangkat Android dan browser gagal men-decode-nya — terlihat
/// dari log `HeifDecoderImpl ... videoFrame is a nullptr` — jadi AVIF
/// dibuang dan file aslinya diarsipkan di luar proyek.)
///
/// Bila gambar gagal dimuat — misalnya file tidak ikut ter-bundle —
/// widget menampilkan monogram "JT" agar halaman tidak error.
class _JobTrackLogo extends StatelessWidget {
  const _JobTrackLogo({required this.size});

  final double size;

  // Path aset dikonstantakan agar tidak ada string path yang tersebar di
  // dalam class.
  static const String _assetPath = 'assets/image/jobtrack.png';

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
      child: Image.asset(
        _assetPath,
        // Gambar memenuhi lingkaran putih; alignment defaultnya sudah center,
        // dan file PNG-nya sendiri sudah dipangkas agar kontennya pas di
        // tengah kanvas.
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _monogram(),
      ),
    );
  }
}

/// Tombol utama: warna solid, lebar penuh.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52, // cukup besar untuk disentuh, tapi tidak berlebihan.
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: JobTrackColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB9C6D3),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Tombol sekunder: outline, lebar penuh.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: JobTrackColors.navy,
          side: const BorderSide(color: Color(0xFFD3DCE6), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
