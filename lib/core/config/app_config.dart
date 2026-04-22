import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  // Android: resetOnError evita crash quando não há lockscreen configurado
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
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
    try {
      final url = await _storage.read(key: _keyBackendUrl)
          .timeout(const Duration(seconds: 3));
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugPrint('SecureStorage getBackendUrl error: $e');
    }
    // Fallback: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyBackendUrl) ?? defaultUrl;
    } catch (_) {}
    return defaultUrl;
  }

  static Future<void> setBackendUrl(String url) async {
    try {
      await _storage.write(key: _keyBackendUrl, value: url);
    } catch (e) {
      debugPrint('SecureStorage setBackendUrl error: $e');
    }
    // Salva também em SharedPreferences como fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBackendUrl, url);
    } catch (_) {}
  }

  static Future<String?> getJwt() async {
    try {
      return await _storage.read(key: 'jwt_token')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  static Future<void> setJwt(String token) async {
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (_) {}
  }

  static Future<void> clearJwt() async {
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (_) {}
  }
}
