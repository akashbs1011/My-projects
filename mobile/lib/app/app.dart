import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/config.dart';
import 'router.dart';
import 'theme.dart';

class ClinicalAiApp extends StatefulWidget {
  const ClinicalAiApp({super.key});

  @override
  State<ClinicalAiApp> createState() => _ClinicalAiAppState();
}

class _ClinicalAiAppState extends State<ClinicalAiApp> {
  AppRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once, from the AuthProvider that the router listens to for
    // redirects. Rebuilding it on every dependency change would reset
    // navigation state.
    _router ??= AppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDevelopment,
      theme: AppTheme.light(),
      routerConfig: _router!.router,
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Caps text scaling so a very large system font cannot break the
        // score rows, while still honouring the person's accessibility setting.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.4,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
