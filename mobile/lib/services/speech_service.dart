import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Optional voice input through the platform's own speech recogniser.
///
/// Availability genuinely varies by device, OS version and installed language
/// packs, so [isAvailable] is reported honestly and the UI tells the person to
/// type instead rather than presenting a button that does nothing.
class SpeechService {
  SpeechService([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialised = false;
  bool _available = false;
  String? _lastError;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;
  String? get lastError => _lastError;

  /// BCP-47 locale tags for the supported languages.
  static const Map<String, String> _locales = {
    'en': 'en_IN',
    'hi': 'hi_IN',
    'kn': 'kn_IN',
    'te': 'te_IN',
    'ta': 'ta_IN',
    'ml': 'ml_IN',
  };

  Future<bool> initialise() async {
    if (_initialised) return _available;
    _initialised = true;
    try {
      _available = await _speech.initialize(
        onError: (error) => _lastError = _describe(error.errorMsg),
        onStatus: (_) {},
        debugLogging: false,
      );
    } catch (e) {
      _available = false;
      _lastError = 'Speech recognition could not start on this device.';
    }
    return _available;
  }

  /// Starts listening. [onResult] fires with interim text and again with the
  /// final transcript, so the UI can show words as they are recognised.
  Future<bool> listen({
    required String language,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await initialise()) return false;
    _lastError = null;

    // Fall back to the device default if the requested language has no pack
    // installed, rather than failing outright.
    final wanted = _locales[language] ?? 'en_IN';
    final installed = await _speech.locales();
    final match = installed
        .where((l) => l.localeId.replaceAll('-', '_') == wanted)
        .toList();

    try {
      await _speech.listen(
        localeId: match.isNotEmpty ? match.first.localeId : null,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
        onResult: (SpeechRecognitionResult result) =>
            onResult(result.recognizedWords, result.finalResult),
      );
      return true;
    } catch (_) {
      _lastError = 'Voice input could not start. Try again or type instead.';
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // Already cancelled.
    }
  }

  String _describe(String code) {
    switch (code) {
      case 'error_permission':
      case 'error_speech_timeout':
        return 'Microphone access was blocked. Allow it in your device settings.';
      case 'error_no_match':
        return 'Nothing was recognised. Try speaking again, closer to the microphone.';
      case 'error_audio':
        return 'No microphone was found.';
      case 'error_network':
        return 'Speech recognition needs a network connection.';
      case 'error_busy':
        return 'The microphone is in use by another app.';
      default:
        return 'Speech recognition stopped unexpectedly.';
    }
  }
}
