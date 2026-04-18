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
          final token = await AppConfig.getJwt();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

    return dio;
  }
}
