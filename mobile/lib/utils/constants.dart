/// Values shared across screens, kept in one place so wording and limits
/// cannot drift between the places they are used.
class AppConstants {
  const AppConstants._();

  // Conditions in the dataset carry 4-17 symptoms (median 6). Fewer than 3
  // selected matches many conditions at once and produces low, unhelpful
  // scores, so 3 is the floor. 6 is the ceiling: beyond that the extra
  // symptoms rarely change the ranking and mostly add unmatched noise.
  static const int minSelectedSymptoms = 3;
  static const int maxSelectedSymptoms = 6;

  /// Only the strongest few candidates are worth showing.
  static const int maxResultsShown = 3;
  static const int symptomSearchLimit = 30;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // Storage keys
  static const String tokenKey = 'clinical_ai_token';
  static const String languageKey = 'clinical_ai_language';

  // Route paths, referenced by constant everywhere so a typo fails to compile
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeResetPassword = '/reset-password';
  static const String routeHome = '/';
  static const String routeResults = '/results';
  static const String routeDisease = '/disease';
  static const String routeHistory = '/history';
  static const String routeProfile = '/profile';
}
