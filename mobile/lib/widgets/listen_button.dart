import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';

/// Plays a spoken version of the results.
///
/// The control only appears once a voice for the current language has been
/// confirmed present on the device. When none exists the widget explains that
/// in the person's own language rather than rendering a button that stays
/// silent when pressed.
class ListenButton extends StatefulWidget {
  const ListenButton({super.key, required this.textBuilder});

  /// Built lazily so the spoken text is assembled only when it is needed.
  final String Function() textBuilder;

  @override
  State<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<ListenButton> {
  // Optimistic by default. The probe can report no voice while the browser is
  // still loading its list, so the button is shown and the real test is an
  // actual attempt to speak. Only a failed attempt hides it.
  bool _available = true;
  bool _playing = false;
  bool _attemptFailed = false;

  // Held directly, because looking a provider up from context during dispose()
  // is not safe once the element is being unmounted.
  TtsService? _tts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tts = context.read<TtsService>();
  }

  @override
  void dispose() {
    // Stop playback if the person navigates away mid-sentence.
    _tts?.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final tts = context.read<TtsService>();
    final language = context.read<LanguageProvider>().code;

    if (_playing) {
      await tts.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }

    setState(() => _playing = true);
    final started = await tts.speak(widget.textBuilder(), language);
    if (!mounted) return;
    if (!started) {
      // The attempt itself failed, so this device genuinely cannot speak this
      // language. Now the message is accurate rather than a guess.
      setState(() {
        _playing = false;
        _attemptFailed = true;
        _available = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!_available && _attemptFailed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.volume_off_outlined,
              size: 16, color: AppTheme.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('audioUnavailable'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _toggle,
        icon: Icon(
          _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
          size: 20,
        ),
        label: Text(l10n.t(_playing ? 'stopAudio' : 'listenToResults')),
        style: FilledButton.styleFrom(
          backgroundColor:
              _playing ? AppTheme.clinicalDark : AppTheme.clinical,
        ),
      ),
    );
  }
}
