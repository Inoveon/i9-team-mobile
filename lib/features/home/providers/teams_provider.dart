import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.description,
    required this.agentCount,
    required this.activeAgents,
    required this.status,
  });

  final String id;
  final String name;
  final String description;
  final int agentCount;
  final int activeAgents;
  final String status;
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

      return TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        agentCount: agents.length,
        activeAgents: activeCount,
        status: teamStatus,
      );
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTeams);
  }
}

final teamsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TeamsNotifier, List<TeamModel>>(
  TeamsNotifier.new,
);
