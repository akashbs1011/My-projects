import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Session state. The router listens to this, so a change here is what moves
/// the person between the signed-in and signed-out parts of the app.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Restores a stored session on launch, so reopening the app does not force
  /// a sign-in. Called by the splash screen.
  Future<void> restoreSession() async {
    if (!await _service.hasSession()) {
      _set(AuthStatus.unauthenticated);
      return;
    }
    try {
      _user = await _service.me();
      _set(AuthStatus.authenticated);
    } on ApiException {
      // A rejected or expired token means no session, not an error to show.
      await _service.logout();
      _set(AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) => _guard(() async {
        _user = await _service.login(email, password);
        _status = AuthStatus.authenticated;
      });

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String preferredLanguage,
  }) =>
      _guard(() async {
        _user = await _service.register(
          name: name,
          email: email,
          password: password,
          confirmPassword: confirmPassword,
          preferredLanguage: preferredLanguage,
        );
        _status = AuthStatus.authenticated;
      });

  Future<Map<String, dynamic>?> forgotPassword(String email) async {
    Map<String, dynamic>? response;
    await _guard(() async => response = await _service.forgotPassword(email));
    return response;
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) =>
      _guard(() => _service.resetPassword(
            token: token,
            password: password,
            confirmPassword: confirmPassword,
          ));

  Future<bool> updateProfile({String? name, String? preferredLanguage}) =>
      _guard(() async {
        _user = await _service.updateProfile(
          name: name,
          preferredLanguage: preferredLanguage,
        );
      });

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _set(AuthStatus.unauthenticated);
  }

  /// Called by ApiClient when the server rejects the token mid-session.
  void onTokenRejected() {
    if (_status == AuthStatus.authenticated) {
      _user = null;
      _set(AuthStatus.unauthenticated);
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Runs [action], turning any ApiException into [error] rather than letting
  /// it reach a widget. Returns whether it succeeded.
  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
