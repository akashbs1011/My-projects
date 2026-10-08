import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/auth_provider.dart';
import 'providers/history_provider.dart';
import 'providers/language_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/symptom_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/history_service.dart';
import 'services/prediction_service.dart';
import 'services/speech_service.dart';
import 'services/token_storage.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dependencies are constructed once here and injected, so no widget reaches
  // for a global and tests can substitute any of them.
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  final authService = AuthService(api: apiClient, tokenStorage: tokenStorage);
  final predictionService = PredictionService(apiClient);
  final historyService = HistoryService(apiClient);
  final speechService = SpeechService();
  final ttsService = TtsService();

  final authProvider = AuthProvider(authService);

  // One place handles a token the server has rejected mid-session.
  apiClient.onUnauthorized = authProvider.onTokenRejected;

  final languageProvider = LanguageProvider();
  await languageProvider.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<SpeechService>.value(value: speechService),
        Provider<TtsService>.value(value: ttsService),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<SymptomProvider>(
          create: (_) => SymptomProvider(predictionService),
        ),
        ChangeNotifierProvider<PredictionProvider>(
          create: (_) => PredictionProvider(predictionService),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider(historyService),
        ),
      ],
      child: const ClinicalAiApp(),
    ),
  );
}
