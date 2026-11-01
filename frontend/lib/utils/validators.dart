class Validators {
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 50;
  static const int emailMaxLength = 255;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 72;

  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[A-Za-z]{2,}$',
  );

  static String? _requiredTrimmed(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

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

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    return null;
  }

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
