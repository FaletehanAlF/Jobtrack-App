import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

/// Kerangka halaman autentikasi (onboarding, login, register).
///
/// Desain sederhana tanpa kartu: gradien lembut sebagai latar dan satu kolom
/// form dipusatkan secara horizontal (lebar maksimum [maxContentWidth]).
/// Pengguliran hanya aktif saat layar benar-benar pendek (mis. keyboard
/// ponsel terbuka) supaya isian tidak terpotong dan tidak ada tampilan
/// yang meluap.
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

  /// Lebar maksimum kolom form. Di atas angka ini kolom tetap terpusat.
  static const double maxContentWidth = 420;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: JobTrackColors.authGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              // Layar pendek memakai padding kecil agar tersisa lebih banyak
              // ruang untuk form.
              final verticalPadding = availableHeight < 600 ? 16.0 : 32.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight - verticalPadding * 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showBackButton) ...[
                        const AuthBackButton(),
                        const SizedBox(height: 12),
                      ],
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: child,
                        ),
                      ),
                      // Sisa tinggi layar dibiarkan kosong di bawah; kolom
                      // form selalu mulai cukup tinggi dari atas.
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Tombol kembali di pojok kiri atas halaman autentikasi.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Kembali',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 22),
        style: IconButton.styleFrom(
          foregroundColor: JobTrackColors.navy,
          minimumSize: const Size(44, 44),
        ),
      ),
    );
  }
}

/// Bagian atas form autentikasi: avatar logo, judul, dan subjudul.
///
/// Semua halaman auth memakai widget ini agar tampilan atasnya seragam.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.brand,
    this.showBadge = false,
  });

  final String title;
  final String? subtitle;

  /// Label kecil di atas judul, mis. "JobTrack" pada onboarding.
  final String? brand;

  /// Menampilkan lencana plus di avatar (dipakai halaman register).
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final brandText = brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: AuthAvatar(showBadge: showBadge)),
        if (brandText != null) ...[
          const SizedBox(height: 18),
          Text(
            brandText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: JobTrackColors.blue,
            ),
          ),
          const SizedBox(height: 10),
        ] else
          const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: JobTrackColors.navy,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitleText != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitleText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Avatar bulat berisi logo JobTrack.
///
/// Lencana plus opsional dipakai untuk memberi isyarat "buat akun" pada
/// halaman register.
class AuthAvatar extends StatelessWidget {
  const AuthAvatar({super.key, this.size = 88, this.showBadge = false});

  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.29;

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: JobTrackColors.authAvatarBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: JobTrackLogo(
              size: size * 0.68,
              backgroundColor: Colors.transparent,
              showShadow: false,
            ),
          ),
          if (showBadge)
            Positioned(
              right: 0,
              top: size * 0.02,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: JobTrackColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: JobTrackColors.surface, width: 3),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: badgeSize * 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Logo JobTrack: gambar bulat dengan latar putih.
///
/// Memakai `jobtrack.png` karena format PNG didukung semua target: Android,
/// iOS, desktop, dan Flutter Web. Bila gambar gagal dimuat, widget menampilkan
/// monogram "JT" agar halaman tidak error.
class JobTrackLogo extends StatelessWidget {
  const JobTrackLogo({
    super.key,
    this.size = 88,
    this.backgroundColor = JobTrackColors.surface,
    this.showShadow = true,
  });

  final double size;
  final Color backgroundColor;
  final bool showShadow;

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
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x140F2137),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      // Padding kecil memberi ruang antara konten PNG dan tepi lingkaran.
      padding: EdgeInsets.all(size * 0.08),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _monogram(),
      ),
    );
  }
}

/// Satu baris form autentikasi: label kecil di atas, lalu field bergaya
/// seragam. Label dipisah dari field agar berada di atas kotak, bukan
/// mengambang di dalam border.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    required this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autocorrect: false,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
          decoration: authFieldDecoration(hint: hint),
        ),
      ],
    );
  }
}

/// Field password dengan tombol tampilkan/sembunyikan.
///
/// Status tersembunyi dikelola di sini agar halaman login/register tidak
/// perlu menyimpan state tambahan.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.validator,
    required this.hint,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String hint;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthFieldLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
          decoration: authFieldDecoration(
            hint: widget.hint,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: JobTrackColors.navyMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol utama: biru solid, lebar penuh, tinggi 54, sudut pill.
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
    final enabled = !loading && onPressed != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(JobTrackRadii.button),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: JobTrackColors.blue.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: JobTrackColors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: JobTrackColors.disabled,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(JobTrackRadii.button),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
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
      ),
    );
  }
}

/// Garis pemisah dengan label di tengah, mis. "Atau".
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'Atau'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: JobTrackColors.authBorder,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: JobTrackColors.navyMuted,
            ),
          ),
        ),
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: JobTrackColors.authBorder,
          ),
        ),
      ],
    );
  }
}

/// Tombol sosial lebar penuh dengan ikon dan label (dipakai onboarding).
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: JobTrackColors.navy,
          backgroundColor: JobTrackColors.surface,
          side: const BorderSide(color: JobTrackColors.authBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JobTrackRadii.social),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// Ikon "G" Google dengan warna solid, tanpa aset tambahan.
class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size,
            height: 1,
            fontWeight: FontWeight.w800,
            color: JobTrackColors.blue,
          ),
        ),
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
            fontSize: 13.5,
            color: JobTrackColors.navyMuted,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: JobTrackColors.blue,
            disabledForegroundColor: JobTrackColors.disabled,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13.5,
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
                fontSize: 13.5,
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

/// Label kecil di atas field form autentikasi.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: JobTrackColors.navy,
      ),
    );
  }
}

/// Gaya seragam untuk semua field di form autentikasi.
///
/// Label dirender terpisah lewat [AuthFieldLabel] agar posisinya berada di
/// atas kotak field, bukan mengambang di dalam border.
InputDecoration authFieldDecoration({
  required String hint,
  Widget? suffixIcon,
}) {
  final radius = BorderRadius.circular(JobTrackRadii.field);
  final restingBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: const BorderSide(color: JobTrackColors.authBorder, width: 1),
  );

  return InputDecoration(
    hintText: hint,
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    filled: true,
    fillColor: JobTrackColors.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    hintStyle: const TextStyle(fontSize: 14, color: JobTrackColors.hint),
    errorStyle: const TextStyle(fontSize: 12, color: JobTrackColors.danger),
    errorMaxLines: 2,
  );
}
