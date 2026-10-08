import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../utils/constants.dart';

/// The active interface language.
///
/// A signed-in person's stored preference wins over the device default, and
/// the choice is persisted so it survives a restart.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider();

  String _code = 'en';
  bool _romanise = false;
  SharedPreferences? _prefs;

  String get code => _code;
  Locale get locale => Locale(_code);
  bool get romanise => _romanise;
  AppLanguage get language => AppLocalizations.languageFor(_code);

  /// True for the scripts the Roman transliteration toggle applies to.
  bool get supportsTransliteration => _code != 'en';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getString(AppConstants.languageKey);
    if (stored != null && AppLocalizations.isSupported(stored)) {
      _code = stored;
    }
    _romanise = _prefs?.getBool('${AppConstants.languageKey}_roman') ?? false;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!AppLocalizations.isSupported(code) || code == _code) return;
    _code = code;
    notifyListeners();
    await _prefs?.setString(AppConstants.languageKey, code);
  }

  Future<void> setRomanise(bool value) async {
    _romanise = value;
    notifyListeners();
    await _prefs?.setBool('${AppConstants.languageKey}_roman', value);
  }

  /// Applies the preference stored on the account after sign-in.
  Future<void> adoptUserPreference(String? preferred) async {
    if (preferred != null && preferred != _code) {
      await setLanguage(preferred);
    }
  }
}
