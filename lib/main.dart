import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detecta rota inicial antes de montar o app (evita tela branca)
  String initialRoute = '/';
  try {
    final url = await AppConfig.getBackendUrl();
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      initialRoute = '/settings';
    }
  } catch (_) {
    initialRoute = '/settings';
  }

  runApp(
    ProviderScope(
      child: App(initialRoute: initialRoute),
    ),
  );
}
