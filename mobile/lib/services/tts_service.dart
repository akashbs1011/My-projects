import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Reads results aloud, so someone who cannot read the screen can still
/// understand the outcome.
///
/// Availability is genuinely uneven: a voice for a given language has to be
/// installed on the device or supplied by the browser, and Indic voices are
/// often missing on desktop Chrome while being present on Android. This class
/// therefore reports what is actually available rather than assuming, and the
/// UI hides the control when a language cannot be spoken instead of offering a
/// button that produces silence.
class TtsService {
  TtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialised = false;
  bool _speaking = false;
  String? _lastError;

  /// Cache of language code -> whether a voice exists, so the check runs once.
  final Map<String, bool> _availability = {};

  bool get isSpeaking => _speaking;
  String? get lastError => _lastError;

  /// BCP-47 tags for the supported languages. Indian variants are preferred
  /// because the medical vocabulary and place names read more naturally.
  static const Map<String, String> _locales = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'kn': 'kn-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'ml': 'ml-IN',
  };

  Future<void> _initialise() async {
    if (_initialised) return;
    _initialised = true;
    try {
      // Slightly slower than default: medical terms and percentages are hard
      // to follow at the standard rate.
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((message) {
        _speaking = false;
        _lastError = 'Speech playback stopped: $message';
      });
    } catch (e) {
      _lastError = 'Speech playback is not available on this device.';
    }
  }

  /// Whether a voice exists for [language]. Falls back to the bare language
  /// code (e.g. 'hi') when the regional variant ('hi-IN') is absent.
  ///
  /// Browsers populate their voice list asynchronously: the first call to
  /// speechSynthesis.getVoices() returns an empty array and the real list
  /// arrives on a later event. Checking once immediately therefore reports
  /// "no voice" on a device that has plenty, so this retries briefly before
  /// concluding anything.
  Future<bool> isAvailable(String language) async {
    if (_availability[language] == true) return true;
    await _initialise();

    final wanted = _locales[language] ?? 'en-IN';

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await _tts.isLanguageAvailable(wanted) == true) {
          _availability[language] = true;
          return true;
        }
        if (await _tts.isLanguageAvailable(language) == true) {
          _availability[language] = true;
          return true;
        }
        // A populated voice list that simply lacks this language is a real
        // negative; an empty one just means the browser has not filled it yet.
        final voices = await _tts.getVoices;
        if (voices is List && voices.isNotEmpty) break;
      } catch (_) {
        // Fall through to the retry.
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    _availability[language] = false;
    return false;
  }

  /// Speaks [text] in [language]. Returns false when no voice was available,
  /// so the caller can explain rather than appearing to do nothing.
  Future<bool> speak(String text, String language) async {
    if (text.trim().isEmpty) return false;
    await _initialise();

    try {
      await stop();
      final locale = _locales[language] ?? 'en-IN';
      try {
        await _tts.setLanguage(locale);
      } catch (_) {
        await _tts.setLanguage(language);
      }
      _speaking = true;
      // Attempt playback regardless of what the availability probe said. On
      // web the probe can be wrong while the voice list is still loading, and
      // a real attempt is the only reliable test.
      await _tts.speak(text);
      return true;
    } catch (e) {
      _speaking = false;
      _lastError = 'Could not play the audio.';
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Already stopped.
    }
    _speaking = false;
  }
}
