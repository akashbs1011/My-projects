import 'package:flutter/material.dart';

import 'strings_en.dart';
import 'strings_hi.dart';
import 'strings_kn.dart';
import 'strings_ml.dart';
import 'strings_ta.dart';
import 'strings_te.dart';

/// A supported interface language.
class AppLanguage {
  const AppLanguage(this.code, this.englishName, this.nativeName);

  final String code;
  final String englishName;
  final String nativeName;
}

/// Interface strings.
///
/// These are UI labels only. Medical content — disease names, explanations,
/// precautions and RAG answers — is translated server-side by the configured
/// translation provider and never from this file, so a missing UI translation
/// can never alter medical wording.
///
/// Any key absent from a language falls back to English rather than showing an
/// empty string or a raw key.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage('en', 'English', 'English'),
    AppLanguage('hi', 'Hindi', 'हिन्दी'),
    AppLanguage('kn', 'Kannada', 'ಕನ್ನಡ'),
    AppLanguage('te', 'Telugu', 'తెలుగు'),
    AppLanguage('ta', 'Tamil', 'தமிழ்'),
    AppLanguage('ml', 'Malayalam', 'മലയാളം'),
  ];

  static List<Locale> get supportedLocales =>
      supportedLanguages.map((l) => Locale(l.code)).toList();

  static const Map<String, Map<String, String>> _tables = {
    'en': stringsEn,
    'hi': stringsHi,
    'kn': stringsKn,
    'te': stringsTe,
    'ta': stringsTa,
    'ml': stringsMl,
  };

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLanguage languageFor(String code) => supportedLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => supportedLanguages.first,
      );

  static bool isSupported(String code) =>
      supportedLanguages.any((l) => l.code == code);

  /// Looks up [key], falling back to English and then to the key itself, so a
  /// gap in a translation table never renders as blank space.
  String t(String key) =>
      _tables[locale.languageCode]?[key] ?? stringsEn[key] ?? key;

  /// Substitutes {name}-style placeholders, e.g. t('matchedCount', {'n': '3'}).
  String tf(String key, Map<String, String> values) {
    var text = t(key);
    values.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.isSupported(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
