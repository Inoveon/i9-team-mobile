import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

/// Plain WebSocket client para capturar interactive_menu via /ws endpoint.
/// Mantém conexão singleton por session.
class RawWsClient {
  RawWsClient._();

  static final Map<String, WebSocketChannel> _channels = {};
  static final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  /// Conecta ao backend WebSocket e se inscreve na sessão.
  static Future<void> subscribe(String session) async {
    if (_channels.containsKey(session)) return; // já conectado

    final baseUrl = await AppConfig.getBackendUrl();
    final token = await AppConfig.ensureJwt();

    // Converte http:// → ws://, https:// → wss://
    final wsUrl = baseUrl.replaceFirst(
      'https://',
      'wss://',
    ).replaceFirst(
      'http://',
      'ws://',
    );

    final url = '$wsUrl/ws?token=${Uri.encodeComponent(token)}';
    final channel = WebSocketChannel.connect(Uri.parse(url));

    _channels[session] = channel;
    _controllers[session] = StreamController<Map<String, dynamic>>.broadcast();

    // Envia subscribe
    channel.sink.add(jsonEncode({'type': 'subscribe', 'session': session}));

    // Escuta mensagens
    channel.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _controllers[session]?.add(msg);
        } catch (_) {}
      },
      onError: (_) {
        _disconnect(session);
      },
      onDone: () {
        _disconnect(session);
      },
    );
  }

  /// Envia texto livre como input para o terminal (tmux send-keys).
  static void sendInput(String session, String text) {
    final channel = _channels[session];
    if (channel == null) return;
    channel.sink.add(jsonEncode({'type': 'input', 'keys': text}));
  }

  /// Envia select_option para uma opção do menu.
  static void selectOption(String session, int index, {int currentIndex = 1}) {
    final channel = _channels[session];
    if (channel == null) return;

    final payload = jsonEncode({
      'type': 'select_option',
      'session': session,
      'value': index.toString(),
      'currentIndex': currentIndex,
    });
    channel.sink.add(payload);
  }

  /// Stream de mensagens (interactive_menu, output, etc.)
  static Stream<Map<String, dynamic>> messages(String session) {
    return _controllers[session]?.stream ?? const Stream.empty();
  }

  /// Desconecta da sessão
  static Future<void> disconnect(String session) async {
    await _disconnect(session);
  }

  static Future<void> _disconnect(String session) async {
    await _channels[session]?.sink.close();
    await _controllers[session]?.close();
    _channels.remove(session);
    _controllers.remove(session);
  }

  /// Desconecta de todas as sessões
  static Future<void> disconnectAll() async {
    for (final session in List.of(_channels.keys)) {
      await _disconnect(session);
    }
  }
}
