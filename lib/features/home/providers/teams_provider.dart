import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Resumo de agente usado para renderizar tags no TeamCard.
class TeamAgentSummary {
  const TeamAgentSummary({
    required this.name,
    required this.active,
  });

  final String name;
  final bool active;
}

class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.description,
    required this.agentCount,
    required this.activeAgents,
    required this.status,
    this.agents = const [],
  });

  final String id;
  final String name;
  final String description;
  final int agentCount;
  final int activeAgents;
  final String status;
  final List<TeamAgentSummary> agents;
}

class TeamsNotifier extends AutoDisposeAsyncNotifier<List<TeamModel>> {
  @override
  Future<List<TeamModel>> build() async {
    return _fetchTeams();
  }

  Future<List<TeamModel>> _fetchTeams() async {
    final dio = await ApiClient.getInstance();

    // Busca teams e sessões tmux em paralelo
    final results = await Future.wait([
      dio.get('/teams'),
      dio.get('/tmux/sessions').catchError((_) => null),
    ]);

    final teamsRaw = results[0]!.data;
    final teamsList = (teamsRaw is Map ? teamsRaw['teams'] : teamsRaw) as List;

    // Conjunto de nomes de sessões tmux ativas
    final sessionsRaw = results[1]?.data;
    final activeSessions = <String>{};
    if (sessionsRaw is Map) {
      final sessions = sessionsRaw['sessions'] as List? ?? [];
      for (final s in sessions) {
        final name = (s as Map)['name'] as String?;
        if (name != null) activeSessions.add(name);
      }
    }

    return teamsList.map((e) {
      final json = e as Map<String, dynamic>;
      final agents = (json['agents'] as List?) ?? [];

      // Conta agentes ativos cruzando sessionName com sessões tmux
      int activeCount = 0;
      for (final a in agents) {
        final sessionName = (a as Map)['sessionName'] as String?;
        if (sessionName != null && activeSessions.contains(sessionName)) {
          activeCount++;
        }
      }

      // Team é ativo se ao menos um agente tem sessão tmux rodando
      // Fallback: verifica se alguma sessão começa com o prefixo do team
      String teamStatus = 'offline';
      if (activeCount > 0) {
        teamStatus = 'active';
      } else if (activeSessions.isNotEmpty) {
        // Prefixo: "i9-team/dev" → "i9-team-dev-"
        final prefix = (json['name'] as String)
                .replaceAll('/', '-')
                .replaceAll(' ', '-')
                .toLowerCase() +
            '-';
        if (activeSessions.any((s) => s.startsWith(prefix))) {
          teamStatus = 'active';
          activeCount = activeSessions.where((s) => s.startsWith(prefix)).length;
        }
      }

      // Monta resumos para renderizar tags no card
      final summaries = agents.map((a) {
        final m = a as Map;
        final sn = m['sessionName'] as String?;
        return TeamAgentSummary(
          name: (m['name'] as String?) ?? '?',
          active: sn != null && activeSessions.contains(sn),
        );
      }).toList();

      return TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        agentCount: agents.length,
        activeAgents: activeCount,
        status: teamStatus,
        agents: summaries,
      );
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTeams);
  }

  /// Inicia o team via `POST /teams/:id/start`. Atualiza a lista ao final.
  /// Lança em caso de erro para o caller exibir toast.
  Future<void> startTeam(String id) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/teams/$id/start');
    await refresh();
  }

  /// Para o team via `POST /teams/:id/stop`. Atualiza a lista ao final.
  Future<void> stopTeam(String id) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/teams/$id/stop');
    await refresh();
  }

  /// Cria novo team via `POST /teams` + agentes via `POST /teams/:id/agents`.
  /// Retorna o id do team criado (pra navegação).
  Future<String> createTeam({
    required String name,
    String? description,
    required List<({String name, String role})> agents,
  }) async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.post<dynamic>('/teams', data: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    final body = resp.data as Map<String, dynamic>;
    final team = body['team'] as Map<String, dynamic>;
    final id = team['id'] as String;
    for (final a in agents) {
      await dio.post('/teams/$id/agents', data: {
        'name': a.name,
        'role': a.role,
      });
    }
    await refresh();
    return id;
  }

  /// Remove team via `DELETE /teams/:id`. Lança em erro pra caller tratar.
  Future<void> deleteTeam(String id) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/teams/$id');
    await refresh();
  }
}

final teamsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TeamsNotifier, List<TeamModel>>(
  TeamsNotifier.new,
);
