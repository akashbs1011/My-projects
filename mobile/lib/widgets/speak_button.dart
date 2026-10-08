import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/speech_service.dart';

/// Optional voice input.
///
/// Availability is checked on the device rather than assumed. When speech
/// recognition is not available the widget says so and points at the search
/// box, instead of showing a button that silently does nothing.
class SpeakButton extends StatefulWidget {
  const SpeakButton({super.key, required this.onTranscript});

  /// Called once, with the final transcript.
  final void Function(String text) onTranscript;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _checking = true;
  bool _available = false;
  bool _listening = false;
  String _partial = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final speech = context.read<SpeechService>();
    final available = await speech.initialise();
    if (!mounted) return;
    setState(() {
      _available = available;
      _checking = false;
      _error = available ? null : speech.lastError;
    });
  }

  Future<void> _toggle() async {
    final speech = context.read<SpeechService>();
    final language = context.read<LanguageProvider>().code;

    if (_listening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() {
      _listening = true;
      _partial = '';
      _error = null;
    });

    final started = await speech.listen(
      language: language,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _partial = text);
        if (isFinal) {
          setState(() => _listening = false);
          if (text.trim().isNotEmpty) widget.onTranscript(text.trim());
        }
      },
    );

    if (!started && mounted) {
      setState(() {
        _listening = false;
        _error = speech.lastError ?? 'Voice input could not start.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_checking) {
      return const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_available) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mic_off_outlined, size: 15, color: AppTheme.inkMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.t('voiceUnsupported'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _toggle,
          icon: Icon(
            _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
            size: 18,
          ),
          label: Text(l10n.t(_listening ? 'stopListening' : 'voiceInput')),
          style: OutlinedButton.styleFrom(
            foregroundColor: _listening ? AppTheme.alertText : AppTheme.ink,
            side: BorderSide(
              color: _listening ? AppTheme.alertBorder : AppTheme.line,
            ),
            backgroundColor: _listening ? AppTheme.alertBg : Colors.white,
          ),
        ),
        if (_listening && _partial.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.tf('voiceHeard', {'text': _partial}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.alertText),
          ),
        ],
      ],
    );
  }
}
