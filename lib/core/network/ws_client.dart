import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class WsClient {
  WsClient._();

  static io.Socket? _socket;

  static Future<io.Socket> getSocket() async {
    if (_socket != null && _socket!.connected) return _socket!;
    final baseUrl = await AppConfig.getBackendUrl();
    final token = await AppConfig.getJwt();

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .enableAutoConnect()
          .build(),
    );

    return _socket!;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static bool get isConnected => _socket?.connected ?? false;
}
