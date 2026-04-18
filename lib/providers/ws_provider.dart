import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/ws_client.dart';

/// Evento recebido via WebSocket de um agente.
class WsEvent {
  const WsEvent({
    required this.teamId,
    required this.agentId,
    required this.type,
    required this.payload,
  });

  final String teamId;
  final String agentId;

  /// Tipo do evento: 'output' | 'status' | 'plan_approval'
  final String type;
  final String payload;

  @override
  String toString() => '[$teamId/$agentId] $type: $payload';
}

/// StreamProvider que emite [WsEvent] conforme chegam mensagens do backend.
///
/// Uso:
/// ```dart
/// final events = ref.watch(wsStreamProvider);
/// events.when(data: (e) => ..., loading: ..., error: ...);
/// ```
final wsStreamProvider = StreamProvider.autoDispose<WsEvent>((ref) async* {
  final controller = StreamController<WsEvent>.broadcast();

  final socket = await WsClient.getSocket();

  void handleOutput(dynamic data) {
    if (data is! Map) return;
    controller.add(WsEvent(
      teamId: (data['teamId'] as String?) ?? '',
      agentId: (data['agentId'] as String?) ?? '',
      type: 'output',
      payload: (data['line'] as String?) ?? '',
    ));
  }

  void handleStatus(dynamic data) {
    if (data is! Map) return;
    controller.add(WsEvent(
      teamId: (data['teamId'] as String?) ?? '',
      agentId: (data['agentId'] as String?) ?? '',
      type: 'status',
      payload: (data['status'] as String?) ?? '',
    ));
  }

  void handlePlanApproval(dynamic data) {
    if (data is! Map) return;
    controller.add(WsEvent(
      teamId: (data['teamId'] as String?) ?? '',
      agentId: (data['agentId'] as String?) ?? '',
      type: 'plan_approval',
      payload: (data['plan'] as String?) ?? '',
    ));
  }

  socket.on('agent_output', handleOutput);
  socket.on('agent_status', handleStatus);
  socket.on('plan_approval', handlePlanApproval);

  ref.onDispose(() {
    socket.off('agent_output', handleOutput);
    socket.off('agent_status', handleStatus);
    socket.off('plan_approval', handlePlanApproval);
    controller.close();
  });

  yield* controller.stream;
});

/// Provider auxiliar que filtra eventos de output por agente.
///
/// Parâmetro: `(teamId, agentId)`
final agentOutputProvider =
    StreamProvider.autoDispose.family<String, (String, String)>(
  (ref, args) {
    final (teamId, agentId) = args;
    return ref.watch(wsStreamProvider.stream).where(
          (e) =>
              e.type == 'output' &&
              e.teamId == teamId &&
              e.agentId == agentId,
        ).map((e) => e.payload);
  },
);
