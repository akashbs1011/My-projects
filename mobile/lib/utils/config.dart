/// Build-time configuration.
///
/// Values arrive through `--dart-define`, so the same source tree produces a
/// development build and a production build without any code change and
/// without secrets being written into the repository.
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
///   flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api
class AppConfig {
  const AppConfig._();

  /// Build flavour. `dev` enables on-screen diagnostics such as the
  /// password-reset token the backend returns while DEBUG=true.
  static const String environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

  static bool get isDevelopment => environment == 'dev';
  static bool get isProduction => environment == 'prod';

  /// Base URL of the FastAPI backend.
  ///
  /// 10.0.2.2 is the Android emulator's alias for the host machine's
  /// localhost. An iOS simulator shares the host network and uses 127.0.0.1.
  /// A physical device needs your machine's LAN address.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const Duration requestTimeout = Duration(seconds: 30);

  static const String appName = 'Clinical AI';
  static const String appVersion = '1.0.0';
}
