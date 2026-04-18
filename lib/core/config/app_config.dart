import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  AppConfig._();

  static const _storage = FlutterSecureStorage();
  static const _keyBackendUrl = 'backend_url';
  static const defaultUrl = 'http://localhost:3100';

  static Future<String> getBackendUrl() async {
    final url = await _storage.read(key: _keyBackendUrl);
    return url ?? defaultUrl;
  }

  static Future<void> setBackendUrl(String url) async {
    await _storage.write(key: _keyBackendUrl, value: url);
  }

  static Future<String?> getJwt() async {
    return _storage.read(key: 'jwt_token');
  }

  static Future<void> setJwt(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<void> clearJwt() async {
    await _storage.delete(key: 'jwt_token');
  }
}
