import 'package:clinical_ai/utils/transliteration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('script detection', () {
    test('identifies each supported Indic script by code-point block', () {
      expect(Transliteration.detectScript('ನನಗೆ ಜ್ವರ ಇದೆ'), 'kn');
      expect(Transliteration.detectScript('मुझे बुखार है'), 'hi');
      expect(Transliteration.detectScript('నాకు జ్వరం ఉంది'), 'te');
      expect(Transliteration.detectScript('எனக்கு காய்ச்சல் உள்ளது'), 'ta');
      expect(Transliteration.detectScript('എനിക്ക് പനി ഉണ്ട്'), 'ml');
    });

    test('returns null for Latin script', () {
      expect(Transliteration.detectScript('I have a fever'), isNull);
      expect(Transliteration.isIndicScript('headache'), isFalse);
    });

    test('picks the dominant script in mixed text', () {
      expect(Transliteration.detectScript('fever ಜ್ವರ ಇದೆ ನನಗೆ'), 'kn');
    });
  });

  group('transliteration', () {
    test('romanises the Kannada example from the specification', () {
      // ನನಗೆ ಜ್ವರ ಇದೆ -> nanage jvara ide
      final roman = Transliteration.toRoman('ನನಗೆ ಜ್ವರ ಇದೆ');
      expect(roman, isNotNull);
      expect(roman, contains('nanage'));
      expect(roman, contains('jvara'));
      expect(roman, contains('ide'));
    });

    test('applies the inherent vowel and cancels it on virama', () {
      // ಕ alone is "ka"; ಕ್ with virama is bare "k".
      expect(Transliteration.toRoman('ಕ'), 'ka');
      expect(Transliteration.toRoman('ಕ್'), 'k');
    });

    test('a vowel sign replaces the inherent vowel rather than adding to it', () {
      expect(Transliteration.toRoman('ಕಿ'), 'ki');
      expect(Transliteration.toRoman('ಕಾ'), 'kā');
    });

    test('the same offsets transliterate every supported script', () {
      expect(Transliteration.toRoman('क'), 'ka');   // Devanagari
      expect(Transliteration.toRoman('ക'), 'ka');   // Malayalam
      expect(Transliteration.toRoman('క'), 'ka');   // Telugu
    });

    test('passes non-Indic characters through untouched', () {
      final roman = Transliteration.toRoman('ಜ್ವರ 39.5');
      expect(roman, contains('39.5'));
    });

    test('returns null for Latin input so callers can hide the Roman line', () {
      expect(Transliteration.toRoman('fever'), isNull);
    });

    test('handles empty input without throwing', () {
      expect(Transliteration.toRoman(''), isNull);
    });
  });
}
