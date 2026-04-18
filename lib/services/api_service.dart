import '../core/network/api_client.dart';
import '../features/home/providers/teams_provider.dart';
import '../features/team/providers/team_provider.dart';

/// Serviço central de API — wraps ApiClient com métodos tipados.
class ApiService {
  ApiService._();

  // ── Teams ────────────────────────────────────────────────────

  /// Lista todos os teams disponíveis no backend.
  static Future<List<TeamModel>> getTeams() async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/teams');
    final list = response.data as List;
    return list
        .map((e) => TeamModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna os detalhes de um team específico.
  static Future<TeamDetailModel> getTeam(String id) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/teams/$id');
    return TeamDetailModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Agents ───────────────────────────────────────────────────

  /// Lista os agentes de um team.
  static Future<List<AgentModel>> getAgents(String teamId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/teams/$teamId/agents');
    final list = response.data as List;
    return list
        .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna o output mais recente de um agente (snapshot REST).
  static Future<List<String>> getAgentOutput(
      String teamId, String agentId) async {
    final dio = await ApiClient.getInstance();
    final response =
        await dio.get('/teams/$teamId/agents/$agentId/output');
    final list = (response.data['lines'] as List?) ?? [];
    return list.map((e) => e.toString()).toList();
  }

  // ── Actions ──────────────────────────────────────────────────

  /// Envia mensagem para o orquestrador de um team via REST.
  static Future<void> sendMessage(String teamId, String message) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/teams/$teamId/message', data: {'message': message});
  }
}
