import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Health do backend — faz `GET /health` a cada 30s.
///
/// Estado:
/// - `AsyncData(true)`  → backend respondendo
/// - `AsyncData(false)` → 4xx/5xx
/// - `AsyncError`       → timeout / rede
final backendHealthProvider = StreamProvider.autoDispose<bool>((ref) async* {
  Future<bool> check() async {
    try {
      final dio = await ApiClient.getInstance();
      final resp = await dio
          .get<dynamic>('/health')
          .timeout(const Duration(seconds: 3));
      final status = resp.statusCode ?? 0;
      return status >= 200 && status < 300;
    } catch (_) {
      return false;
    }
  }

  // Primeiro tick imediato, depois a cada 30s até o provider sair de scope.
  yield await check();
  final timer = Stream<void>.periodic(const Duration(seconds: 30));
  await for (final _ in timer) {
    yield await check();
  }
});
