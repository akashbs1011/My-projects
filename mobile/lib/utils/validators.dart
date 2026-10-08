/// Form validation. Every message says what is wrong and what to do about it.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your name.';
    if (v.length < 2) return 'Use at least 2 characters.';
    if (v.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    // Mirrors the backend rule in schemas/auth.py so the person finds out here
    // rather than after a round trip.
    final hasLetter = v.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = v.contains(RegExp(r'\d'));
    if (!hasLetter || !hasDigit) return 'Include both letters and numbers.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Re-enter your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? notEmpty(String? value, String field) {
    if ((value ?? '').trim().isEmpty) return 'Enter $field.';
    return null;
  }
}
