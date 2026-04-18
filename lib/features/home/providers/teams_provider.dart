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

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        agentCount: (json['agentCount'] as int?) ?? 0,
        activeAgents: (json['activeAgents'] as int?) ?? 0,
        status: (json['status'] as String?) ?? 'offline',
      );
}

class TeamsNotifier extends AutoDisposeAsyncNotifier<List<TeamModel>> {
  @override
  Future<List<TeamModel>> build() async {
    return _fetchTeams();
  }

  Future<List<TeamModel>> _fetchTeams() async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/api/teams');
    final list = response.data as List;
    return list.map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
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
