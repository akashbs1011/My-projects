import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/language_selector.dart';

/// Shared frame for the four authentication screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.mist,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.clinical,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.monitor_heart_outlined,
                            size: 19, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.t('appName'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const LanguageSelector(),
                ],
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.headlineSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 22),
                      child,
                    ],
                  ),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 18),
                Center(child: footer!),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.t('disclaimer'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
