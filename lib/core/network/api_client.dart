import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Future<Dio> getInstance() async {
    if (_instance != null) return _instance!;
    final baseUrl = await AppConfig.getBackendUrl();
    _instance = _buildDio(baseUrl);
    return _instance!;
  }

  static void reset() {
    _instance = null;
  }

  static Dio _buildDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Garante JWT (faz login automático se necessário)
          try {
            final token = await AppConfig.ensureJwt();
            options.headers['Authorization'] = 'Bearer $token';
          } catch (_) {
            // Sem token — tenta sem autenticação
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Se 401, limpa JWT e tenta relogar uma vez
          if (error.response?.statusCode == 401) {
            await AppConfig.clearJwt();
            try {
              final token = await AppConfig.autoLogin();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              final resp = await dio.fetch(opts);
              return handler.resolve(resp);
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );

    return dio;
  }
}
