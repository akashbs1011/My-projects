/// A failed API call, already turned into something a person can read.
///
/// Screens render [message] directly, which is why no screen ever has to
/// inspect a status code or print a raw error object.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  /// True when the session is over and the router should send the person to
  /// sign in rather than retrying.
  bool get isUnauthorized => statusCode == 401;

  /// True when the backend is up but a component (model, database, index)
  /// is not loaded.
  bool get isServiceUnavailable => statusCode == 503;

  @override
  String toString() => message;
}
