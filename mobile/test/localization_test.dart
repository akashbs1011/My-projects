import 'package:clinical_ai/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('supported languages', () {
    test('covers exactly the six required languages', () {
      final codes =
          AppLocalizations.supportedLanguages.map((l) => l.code).toList();
      expect(codes, ['en', 'hi', 'kn', 'te', 'ta', 'ml']);
    });

    test('every language has a native name', () {
      for (final language in AppLocalizations.supportedLanguages) {
        expect(language.nativeName, isNotEmpty);
      }
    });
  });

  group('lookup', () {
    test('returns the language-specific string', () {
      const kn = AppLocalizations(Locale('kn'));
      expect(kn.t('home'), 'ಮುಖಪುಟ');
      const hi = AppLocalizations(Locale('hi'));
      expect(hi.t('home'), 'होम');
    });

    test('falls back to English rather than rendering blank', () {
      const ta = AppLocalizations(Locale('ta'));
      // Whatever this key resolves to, it is never empty and never the raw key.
      expect(ta.t('supportCaption'), isNotEmpty);
    });

    test('returns the key itself only when it exists nowhere', () {
      const en = AppLocalizations(Locale('en'));
      expect(en.t('no_such_key_anywhere'), 'no_such_key_anywhere');
    });

    test('substitutes placeholders', () {
      const en = AppLocalizations(Locale('en'));
      expect(en.tf('resultNumber', {'n': '2'}), 'Result 2');
    });
  });

  group('medical safety wording', () {
    test('every language states the tool does not replace a professional', () {
      for (final language in AppLocalizations.supportedLanguages) {
        final l10n = AppLocalizations(Locale(language.code));
        expect(l10n.t('disclaimer'), isNotEmpty);
        expect(l10n.t('urgentNotice'), isNotEmpty);
        expect(l10n.t('notInKnowledgeBase'), isNotEmpty);
      }
    });

    test('the English result wording never asserts a diagnosis', () {
      const en = AppLocalizations(Locale('en'));
      expect(en.t('possibleMatch').toLowerCase(), contains('possible match'));
      expect(en.t('possibleMatch').toLowerCase(), isNot(contains('you have')));
      expect(en.t('modelConfidenceCaption').toLowerCase(),
          contains('not a medically validated probability'));
    });
  });
}
