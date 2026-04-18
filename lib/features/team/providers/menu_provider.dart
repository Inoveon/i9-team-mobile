import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/raw_ws_client.dart';
import '../models/menu_model.dart';

// Simple family provider que se inscreve no WS quando sessionName muda
final menuProvider = StreamProvider.autoDispose.family<InteractiveMenu?, String>(
  (ref, sessionName) {
    // Subscribe ao WS
    RawWsClient.subscribe(sessionName);

    // Stream de mensagens filtradas para interactive_menu
    final messageStream = RawWsClient.messages(sessionName);

    return messageStream
        .where((msg) => msg['type'] == 'interactive_menu')
        .map((msg) {
      return InteractiveMenu.fromJson(msg, sessionName);
    });
  },
);

// Action para enviar select_option
Future<void> selectMenuOption(WidgetRef ref, String sessionName, int index) async {
  RawWsClient.selectOption(sessionName, index, currentIndex: 1);
}
