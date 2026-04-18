import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';

class AgentModel {
  const AgentModel({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.outputLines,
    this.isOrchestrator = false,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  final List<String> outputLines;
  final bool isOrchestrator;

  AgentModel copyWith({List<String>? outputLines, String? status}) => AgentModel(
        id: id,
        name: name,
        role: role,
        status: status ?? this.status,
        outputLines: outputLines ?? this.outputLines,
        isOrchestrator: isOrchestrator,
      );

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: (json['role'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'offline',
        outputLines: List<String>.from((json['outputLines'] as List?) ?? []),
        isOrchestrator: (json['isOrchestrator'] as bool?) ?? false,
      );
}

class TeamDetailModel {
  const TeamDetailModel({required this.id, required this.name, required this.agents});
  final String id;
  final String name;
  final List<AgentModel> agents;

  factory TeamDetailModel.fromJson(Map<String, dynamic> json) => TeamDetailModel(
        id: json['id'] as String,
        name: json['name'] as String,
        agents: (json['agents'] as List? ?? [])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TeamNotifier extends AutoDisposeFamilyAsyncNotifier<TeamDetailModel, String> {
  @override
  Future<TeamDetailModel> build(String arg) async {
    teamId = arg;
    final detail = await _fetchTeam(teamId);
    _connectWs(teamId);
    return detail;
  }

  late final String teamId;

  Future<TeamDetailModel> _fetchTeam(String id) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/api/teams/$id');
    return TeamDetailModel.fromJson(response.data as Map<String, dynamic>);
  }

  void _connectWs(String id) async {
    final socket = await WsClient.getSocket();
    socket.emit('join_team', id);
    socket.on('agent_output', (data) {
      if (data is Map) {
        _onAgentOutput(data['agentId'] as String, data['line'] as String);
      }
    });
    socket.on('agent_status', (data) {
      if (data is Map) {
        _onAgentStatus(data['agentId'] as String, data['status'] as String);
      }
    });
  }

  void _onAgentOutput(String agentId, String line) {
    final current = state.valueOrNull;
    if (current == null) return;
    final agents = current.agents.map((a) {
      if (a.id != agentId) return a;
      final lines = [...a.outputLines, line];
      return a.copyWith(outputLines: lines.length > 30 ? lines.sublist(lines.length - 30) : lines);
    }).toList();
    state = AsyncData(TeamDetailModel(id: current.id, name: current.name, agents: agents));
  }

  void _onAgentStatus(String agentId, String status) {
    final current = state.valueOrNull;
    if (current == null) return;
    final agents = current.agents.map((a) => a.id == agentId ? a.copyWith(status: status) : a).toList();
    state = AsyncData(TeamDetailModel(id: current.id, name: current.name, agents: agents));
  }

  Future<void> sendMessage(String message) async {
    final socket = await WsClient.getSocket();
    socket.emit('orchestrator_message', {'teamId': state.valueOrNull?.id, 'message': message});
  }
}

final teamNotifierProvider =
    AutoDisposeFamilyAsyncNotifierProvider<TeamNotifier, TeamDetailModel, String>(
  TeamNotifier.new,
);
