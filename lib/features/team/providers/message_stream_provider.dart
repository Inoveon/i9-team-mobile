import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_event.dart';
import '../../../core/network/raw_ws_client.dart';

/// Estado do stream de mensagens tipadas de um agente.
class MessageStreamState {
  final List<MessageEvent> events;
  final bool connected;
  final String? error;

  const MessageStreamState({
    this.events = const [],
    this.connected = false,
    this.error,
  });

  MessageStreamState copyWith({
    List<MessageEvent>? events,
    bool? connected,
    String? error,
  }) =>
      MessageStreamState(
        events: events ?? this.events,
        connected: connected ?? this.connected,
        error: error ?? this.error,
      );
}

/// Notifier que escuta o evento `message_stream` do WebSocket para uma sessão.
class MessageStreamNotifier extends StateNotifier<MessageStreamState> {
  MessageStreamNotifier(this._session) : super(const MessageStreamState()) {
    _connect();
  }

  final String _session;
  StreamSubscription<Map<String, dynamic>>? _sub;

  Future<void> _connect() async {
    try {
      await RawWsClient.subscribe(_session);
      state = state.copyWith(connected: true);

      _sub = RawWsClient.messages(_session).listen((msg) {
        final type = msg['type'] as String?;

        if (type == 'message_stream') {
          final rawEvents = msg['events'];
          if (rawEvents is List) {
            final newEvents = rawEvents
                .whereType<Map<String, dynamic>>()
                .map((e) => MessageEvent.fromJson(e))
                .toList();

            // Acumula — não substitui (append ao histórico)
            state = state.copyWith(
              events: [...state.events, ...newEvents],
            );
          }
        }
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Limpa histórico de eventos (ex: ao trocar de agente)
  void clear() => state = const MessageStreamState();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider parametrizado por sessionName.
final messageStreamProvider = StateNotifierProvider.family<
    MessageStreamNotifier, MessageStreamState, String>(
  (ref, session) => MessageStreamNotifier(session),
);
