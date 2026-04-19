import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../team/models/message_event.dart';
import '../../team/providers/team_provider.dart';
import '../../team/providers/message_stream_provider.dart';

/// Estado consolidado da AgentScreen.
class AgentDetailState {
  final AgentModel? agent;
  final List<MessageEvent> events;
  final bool connected;
  final bool isInPlanMode;
  final String? error;

  const AgentDetailState({
    this.agent,
    this.events = const [],
    this.connected = false,
    this.isInPlanMode = false,
    this.error,
  });

  AgentDetailState copyWith({
    AgentModel? agent,
    List<MessageEvent>? events,
    bool? connected,
    bool? isInPlanMode,
    String? error,
  }) =>
      AgentDetailState(
        agent: agent ?? this.agent,
        events: events ?? this.events,
        connected: connected ?? this.connected,
        isInPlanMode: isInPlanMode ?? this.isInPlanMode,
        error: error ?? this.error,
      );
}

typedef AgentDetailKey = ({String teamId, String agentId});

/// Notifier que combina teamNotifierProvider + messageStreamProvider
/// para exibir detalhes de um agente específico com detecção de Plan Mode.
class AgentDetailNotifier
    extends AutoDisposeFamilyNotifier<AgentDetailState, AgentDetailKey> {
  @override
  AgentDetailState build(AgentDetailKey arg) {
    // Observa o team para obter dados do agente
    final teamAsync = ref.watch(teamNotifierProvider(arg.teamId));
    final agent = teamAsync.valueOrNull?.agents
        .where((a) => a.id == arg.agentId)
        .firstOrNull;

    // Observa o stream de mensagens tipadas para a sessão do agente
    final session = agent?.sessionName ?? arg.agentId;
    final streamState = ref.watch(messageStreamProvider(session));

    // Detecta Plan Mode: qualquer evento planMode nos últimos eventos
    // que ainda não foi respondido (nenhum userInput após ele)
    final isInPlanMode = _detectPlanMode(streamState.events);

    return AgentDetailState(
      agent: agent,
      events: streamState.events,
      connected: streamState.connected,
      isInPlanMode: isInPlanMode,
      error: streamState.error,
    );
  }

  /// Detecta se o agente está aguardando aprovação de plano.
  ///
  /// Lógica: se existe um evento [MessageEventType.planMode] e nenhum
  /// [MessageEventType.userInput] posterior a ele, o agente está aguardando.
  static bool _detectPlanMode(List<MessageEvent> events) {
    if (events.isEmpty) return false;

    int lastPlanModeIdx = -1;
    int lastUserInputIdx = -1;

    for (int i = 0; i < events.length; i++) {
      if (events[i].isPlanMode) lastPlanModeIdx = i;
      if (events[i].type == MessageEventType.userInput) lastUserInputIdx = i;
    }

    return lastPlanModeIdx > -1 && lastPlanModeIdx > lastUserInputIdx;
  }
}

final agentDetailProvider = NotifierProvider.autoDispose
    .family<AgentDetailNotifier, AgentDetailState, AgentDetailKey>(
  AgentDetailNotifier.new,
);
