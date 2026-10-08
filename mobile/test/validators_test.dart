import 'package:clinical_ai/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts valid addresses', () {
      expect(Validators.email('person@example.com'), isNull);
      expect(Validators.email('first.last+tag@sub.example.co.in'), isNull);
    });

    test('rejects malformed addresses with an actionable message', () {
      expect(Validators.email(''), 'Enter your email address.');
      expect(Validators.email('not-an-email'), contains('valid'));
      expect(Validators.email('missing@domain'), isNotNull);
    });
  });

  group('password', () {
    test('mirrors the backend rule so failures surface before a round trip', () {
      // schemas/auth.py rejects all-letter and all-digit passwords.
      expect(Validators.password('lettersonly'), contains('letters and numbers'));
      expect(Validators.password('12345678'), contains('letters and numbers'));
      expect(Validators.password('Str0ngPass'), isNull);
    });

    test('enforces the minimum length', () {
      expect(Validators.password('Ab1'), contains('8 characters'));
    });
  });

  group('confirmPassword', () {
    test('flags a mismatch', () {
      expect(Validators.confirmPassword('abc123XY', 'different1'),
          'Passwords do not match.');
    });

    test('accepts a match', () {
      expect(Validators.confirmPassword('abc123XY', 'abc123XY'), isNull);
    });
  });

  group('name', () {
    test('requires two characters and caps at eighty', () {
      expect(Validators.name('A'), contains('2 characters'));
      expect(Validators.name('Asha'), isNull);
      expect(Validators.name('x' * 81), contains('80'));
    });
  });
}
