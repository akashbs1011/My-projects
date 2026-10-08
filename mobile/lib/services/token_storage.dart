import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';

/// Stores the JWT in the Android Keystore / iOS Keychain rather than in plain
/// preferences, so it is not readable from a device backup or by another app.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String?> read() async {
    if (_cached != null) return _cached;
    try {
      _cached = await _storage.read(key: AppConstants.tokenKey);
    } catch (_) {
      // A keystore that cannot be opened is treated as "no session" rather
      // than crashing the app on launch.
      _cached = null;
    }
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    try {
      await _storage.write(key: AppConstants.tokenKey, value: token);
    } catch (_) {
      // Kept in memory for this session even if persisting failed.
    }
  }

  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: AppConstants.tokenKey);
    } catch (_) {
      // Nothing further to do; the in-memory copy is already gone.
    }
  }
}
