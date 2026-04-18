import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  AppConfig._();

  static const _storage = FlutterSecureStorage();
  static const _keyBackendUrl = 'backend_url';
  static const defaultUrl = 'http://localhost:4020';

  // Credenciais padrão (espelham o .env do backend)
  static const defaultUser = 'admin';
  static const defaultPass = 'i9team';

  /// Garante que existe um JWT válido — faz login automático se necessário.
  static Future<String> ensureJwt() async {
    final existing = await getJwt();
    if (existing != null) return existing;
    return autoLogin();
  }

  /// Faz login no backend e persiste o access_token.
  static Future<String> autoLogin({String? user, String? pass}) async {
    final baseUrl = await getBackendUrl();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
    ));
    final resp = await dio.post('/auth/login', data: {
      'username': user ?? defaultUser,
      'password': pass ?? defaultPass,
    });
    // Backend retorna { access_token: "..." }
    final token = (resp.data['access_token'] as String?) ??
        (resp.data['token'] as String?);
    if (token == null) throw Exception('Login falhou: token não retornado');
    await setJwt(token);
    return token;
  }

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
