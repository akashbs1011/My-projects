import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/config.dart';

/// Shown while the stored session is checked.
///
/// The router holds every route here until AuthStatus resolves, so a returning
/// person goes straight to Home instead of flashing the sign-in screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    await auth.restoreSession();
    if (!mounted) return;
    // Adopt the language stored on the account once the profile is known.
    await context
        .read<LanguageProvider>()
        .adoptUserPreference(auth.user?.preferredLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.clinical,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.monitor_heart_outlined,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(l10n.t('appName'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                l10n.t('tagline'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 34),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const Spacer(),
              Text(
                l10n.t('disclaimer'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (AppConfig.isDevelopment) ...[
                const SizedBox(height: 10),
                Text(
                  '${l10n.t('devMode')} · ${AppConfig.apiBaseUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
