/// Validator untuk form autentikasi.
///
/// Semua aturan di sini mengikuti `backend/src/validations/auth.validation.ts`
/// agar pesan di aplikasi sama dengan yang akan diterima server:
///
/// | Field           | Aturan backend                              |
/// |-----------------|---------------------------------------------|
/// | username        | trim, 3–50 karakter                         |
/// | email           | trim, maks 255 karakter, format email valid |
/// | password        | 8–72 karakter (tidak di-trim)               |
/// | confirmPassword | harus sama dengan password                  |
///
/// Perbedaan penting yang ikut ditiru:
/// - username dan email **di-trim** lebih dulu, jadi spasi di awal/akhir tidak
///   dihitung sebagai karakter.
/// - password **tidak** di-trim, jadi spasi ikut dihitung seperti di backend.
///
/// Setiap fungsi mengembalikan `null` bila valid, atau pesan error bila tidak,
/// sehingga bisa langsung dipakai pada properti `validator` di `TextFormField`.
class Validators {
  // Batas panjang, diambil dari schema backend.
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 50;
  static const int emailMaxLength = 255;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 72;

  // Format email. Harus ada titik di domain dan TLD minimal 2 huruf,
  // karena backend menolak "a@b" maupun "a@b.c".
  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[A-Za-z]{2,}$',
  );

  /// Memastikan nilai tidak kosong setelah di-trim.
  static String? _requiredTrimmed(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Username wajib diisi, 3–50 karakter setelah di-trim.
  static String? username(String? value) {
    final requiredError = _requiredTrimmed(value, 'Username wajib diisi');
    if (requiredError != null) return requiredError;

    final length = value!.trim().length;

    if (length < usernameMinLength) {
      return 'Username minimal $usernameMinLength karakter';
    }
    if (length > usernameMaxLength) {
      return 'Username maksimal $usernameMaxLength karakter';
    }

    return null;
  }

  /// Email wajib diisi dan formatnya valid.
  ///
  /// Batas 255 karakter berlaku pada register. Untuk login dipakai fungsi yang
  /// sama, dan itu tidak masalah karena email sepanjang itu tidak akan pernah
  /// bisa terdaftar.
  static String? email(String? value) {
    final requiredError = _requiredTrimmed(value, 'Email wajib diisi');
    if (requiredError != null) return requiredError;

    final email = value!.trim();

    if (email.length > emailMaxLength) {
      return 'Email maksimal $emailMaxLength karakter';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  /// Password untuk pendaftaran: 8–72 karakter.
  ///
  /// Nilai tidak di-trim, sama seperti backend. Batas 72 mengikuti batas bcrypt
  /// yang memotong input di atas 72 byte.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';

    if (value.length < passwordMinLength) {
      return 'Password minimal $passwordMinLength karakter';
    }
    if (value.length > passwordMaxLength) {
      return 'Password maksimal $passwordMaxLength karakter';
    }

    return null;
  }

  /// Password untuk login: hanya wajib diisi.
  ///
  /// Backend memakai aturan berbeda saat login (minimal 1 karakter, tanpa batas
  /// maksimum), jadi aturan panjang password pendaftaran tidak dipakai di sini.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    return null;
  }

  /// Konfirmasi password wajib diisi dan harus sama dengan [password].
  ///
  /// Perbandingan memakai nilai apa adanya (tanpa trim), mengikuti backend yang
  /// membandingkan kedua nilai secara langsung.
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }
    if (value != password) {
      return 'Konfirmasi password tidak sama';
    }

    return null;
  }
}
