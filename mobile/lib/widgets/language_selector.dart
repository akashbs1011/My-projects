import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';

/// Compact language switcher for the app bar.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.onChanged});

  /// Lets a screen react to the change, e.g. by refetching translated labels.
  final void Function(String code)? onChanged;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      tooltip: l10n.t('language'),
      position: PopupMenuPosition.under,
      initialValue: provider.code,
      onSelected: (code) async {
        await context.read<LanguageProvider>().setLanguage(code);
        onChanged?.call(code);
      },
      itemBuilder: (context) => [
        for (final language in AppLocalizations.supportedLanguages)
          PopupMenuItem<String>(
            value: language.code,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: language.code == provider.code
                      ? const Icon(Icons.check_rounded,
                          size: 17, color: AppTheme.clinical)
                      : null,
                ),
                Text(language.nativeName),
                if (language.code != 'en') ...[
                  const SizedBox(width: 6),
                  Text(
                    language.englishName,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.inkMuted),
                  ),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 16, color: AppTheme.inkMuted),
            const SizedBox(width: 6),
            Text(
              provider.language.nativeName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 19, color: AppTheme.inkMuted),
          ],
        ),
      ),
    );
  }
}
