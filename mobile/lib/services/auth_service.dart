import '../models/user.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Calls the /api/auth and /api/users endpoints.
///
/// Passwords are sent over the wire once and never held in memory or written
/// to storage by this layer; the backend hashes them with bcrypt.
class AuthService {
  AuthService({required ApiClient api, required TokenStorage tokenStorage})
      : _api = api,
        _tokens = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String preferredLanguage,
  }) async {
    final data = await _api.post('/auth/register', withAuth: false, body: {
      'name': name,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
      'preferred_language': preferredLanguage,
    });
    await _tokens.write(data['access_token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> login(String email, String password) async {
    final data = await _api.post('/auth/login', withAuth: false, body: {
      'email': email,
      'password': password,
    });
    await _tokens.write(data['access_token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async =>
      User.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      // The token is discarded locally whatever the server replies.
      await _tokens.clear();
    }
  }

  /// Returns the raw response so a development build can surface the reset
  /// token the backend includes only while DEBUG=true.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final data = await _api
        .post('/auth/forgot-password', withAuth: false, body: {'email': email});
    return (data as Map).cast<String, dynamic>();
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) =>
      _api.post('/auth/reset-password', withAuth: false, body: {
        'token': token,
        'password': password,
        'confirm_password': confirmPassword,
      });

  Future<User> updateProfile({String? name, String? preferredLanguage}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (preferredLanguage != null) body['preferred_language'] = preferredLanguage;
    final data = await _api.patch('/users/profile', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> hasSession() async =>
      (await _tokens.read())?.isNotEmpty ?? false;
}
