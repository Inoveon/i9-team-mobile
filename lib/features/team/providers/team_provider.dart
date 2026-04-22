import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class AgentModel {
  const AgentModel({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.outputLines,
    this.sessionName,
    this.isOrchestrator = false,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  final List<String> outputLines;
  final String? sessionName;
  final bool isOrchestrator;

  AgentModel copyWith({List<String>? outputLines, String? status}) => AgentModel(
        id: id,
        name: name,
        role: role,
        status: status ?? this.status,
        outputLines: outputLines ?? this.outputLines,
        sessionName: sessionName,
        isOrchestrator: isOrchestrator,
      );

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
        id: (json['id'] as String?) ?? 'unknown',
        name: (json['name'] as String?) ?? 'Agent',
        role: (json['role'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'offline',
        outputLines: List<String>.from((json['outputLines'] as List?) ?? []),
        sessionName: (json['sessionName'] as String?) ?? '',
        isOrchestrator: (json['isOrchestrator'] as bool?) ?? false,
      );
}

class TeamDetailModel {
  const TeamDetailModel({required this.id, required this.name, required this.agents});
  final String id;
  final String name;
  final List<AgentModel> agents;

  factory TeamDetailModel.fromJson(Map<String, dynamic> json) => TeamDetailModel(
        id: (json['id'] as String?) ?? 'unknown',
        name: (json['name'] as String?) ?? 'Team',
        agents: (json['agents'] as List? ?? [])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TeamNotifier extends AutoDisposeFamilyAsyncNotifier<TeamDetailModel, String> {
  @override
  Future<TeamDetailModel> build(String arg) async {
    teamId = arg;
    return _fetchTeam(teamId);
  }

  late final String teamId;

  Future<TeamDetailModel> _fetchTeam(String id) async {
    final dio = await ApiClient.getInstance();

    // Busca dados do team e status tmux em paralelo
    final results = await Future.wait([
      dio.get('/teams/$id'),
      dio.get('/teams/$id/agents/status').catchError((_) => null),
    ]);

    final data = results[0]!.data as Map<String, dynamic>;
    final teamJson = (data['team'] as Map<String, dynamic>?) ?? data;

    // Monta mapa agentId → active (baseado em sessões tmux)
    final statusMap = <String, bool>{};
    final statusData = results[1]?.data;
    if (statusData is Map) {
      final agentsList = (statusData['agents'] as List?) ?? [];
      for (final a in agentsList) {
        final agentMap = a as Map;
        final agentId = agentMap['id'] as String?;
        final active = agentMap['active'] as bool? ?? false;
        if (agentId != null) statusMap[agentId] = active;
      }
    }

    final team = TeamDetailModel.fromJson(teamJson);

    // Enriquecer agentes com status real do tmux
    // Se statusMap estiver vazio (backend offline/sem tmux), mostrar active por padrão
    final enrichedAgents = team.agents.map((agent) {
      final isActive = statusMap.isEmpty ? true : (statusMap[agent.id] ?? false);
      return agent.copyWith(status: isActive ? 'active' : 'offline');
    }).toList();

    return TeamDetailModel(id: team.id, name: team.name, agents: enrichedAgents);
  }

  /// Envia mensagem via REST `POST /teams/:id/message`.
  ///
  /// Substitui a implementação anterior que usava `socket.emit('orchestrator_message',…)`
  /// — socket.io que **não existe no backend** (só há raw WebSocket em `/ws`).
  /// O endpoint REST resolve em `sendKeys(sessionName, content)` no backend
  /// (mesmo efeito do WS `input`, porém com error handling HTTP correto).
  ///
  /// [agentId] opcional: se omitido, backend entrega ao orquestrador.
  Future<void> sendMessage(String message, {String? agentId}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final dio = await ApiClient.getInstance();
    final data = <String, dynamic>{'content': message};
    if (agentId != null && agentId.isNotEmpty) data['agentId'] = agentId;
    await dio.post('/teams/${current.id}/message', data: data);
  }

  /// Adiciona agente via `POST /teams/:id/agents` + refresh.
  Future<void> addAgent({required String name, required String role}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final dio = await ApiClient.getInstance();
    await dio.post('/teams/${current.id}/agents', data: {
      'name': name,
      'role': role,
    });
    ref.invalidateSelf();
    await future;
  }

  /// Remove agente via `DELETE /teams/:id/agents/:agentId` + refresh.
  Future<void> removeAgent(String agentId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final dio = await ApiClient.getInstance();
    await dio.delete('/teams/${current.id}/agents/$agentId');
    ref.invalidateSelf();
    await future;
  }
}

final teamNotifierProvider =
    AsyncNotifierProvider.autoDispose.family<TeamNotifier, TeamDetailModel, String>(
  TeamNotifier.new,
);
