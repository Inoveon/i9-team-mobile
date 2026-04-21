import 'dart:io' show SocketException;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Resultado do envio de mensagem — carrega métricas sobre anexos aceitos /
/// rejeitados pelo backend (Issue backend #3 — 207 Multi-Status).
class MessageSendResult {
  const MessageSendResult({
    required this.accepted,
    required this.rejected,
    required this.partial,
  });

  /// UUIDs de anexos aceitos pelo backend (existiam em UPLOAD_DIR/{teamId}/).
  final List<String> accepted;

  /// UUIDs de anexos rejeitados (com motivo, tipicamente `not_found`).
  final List<({String id, String reason})> rejected;

  /// `true` quando pelo menos um anexo foi rejeitado mas o envio seguiu (HTTP 207).
  final bool partial;

  bool get hasAttachments => accepted.isNotEmpty || rejected.isNotEmpty;
}

/// Exceção semântica para erros de envio com códigos HTTP mapeados.
class MessageSendException implements Exception {
  const MessageSendException({
    required this.message,
    required this.statusCode,
  });
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

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
  /// Onda 5 (Issue backend #3): aceita [attachmentIds] — UUIDs retornados por
  /// `POST /upload/image`. Backend valida existência + ownership (subdir do
  /// team) e retorna:
  ///   * 200 — tudo OK
  ///   * 207 — mensagem aceita, mas alguns anexos foram rejeitados (not_found).
  ///           `attachmentsRejected[]` vem na resposta.
  ///   * 400 — payload inválido OU todos os anexos falharam sem texto.
  ///
  /// [agentId] opcional: se omitido, backend entrega ao orquestrador.
  ///
  /// Implementa retry único em erro de rede transitório (SocketException /
  /// timeouts). 4xx/5xx retornam como [MessageSendException].
  Future<MessageSendResult> sendMessage(
    String message, {
    String? agentId,
    List<String> attachmentIds = const [],
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      throw const MessageSendException(
        message: 'Team ainda não carregado',
        statusCode: null,
      );
    }
    final dio = await ApiClient.getInstance();
    final data = <String, dynamic>{'content': message};
    if (agentId != null && agentId.isNotEmpty) data['agentId'] = agentId;
    if (attachmentIds.isNotEmpty) data['attachmentIds'] = attachmentIds;

    final path = '/teams/${current.id}/message';

    Future<Response<dynamic>> attempt() => dio.post(
          path,
          data: data,
          options: Options(
            // Aceitar 207 como status válido para processar attachmentsRejected
            validateStatus: (code) => code != null && code < 400,
          ),
        );

    Response<dynamic> response;
    try {
      response = await attempt();
    } on DioException catch (e) {
      final isTransient = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException;
      if (!isTransient) {
        throw _mapDioError(e);
      }
      // Retry único em erros transitórios
      try {
        response = await attempt();
      } on DioException catch (e2) {
        throw _mapDioError(e2);
      }
    }

    final body = (response.data is Map<String, dynamic>)
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    final used = (body['attachmentsUsed'] as List?)?.cast<String>() ?? const [];
    final rejectedRaw = (body['attachmentsRejected'] as List?) ?? const [];
    final rejected = rejectedRaw
        .whereType<Map>()
        .map((m) => (
              id: (m['id'] as String?) ?? '',
              reason: (m['reason'] as String?) ?? 'unknown',
            ))
        .toList();

    return MessageSendResult(
      accepted: used,
      rejected: rejected,
      partial: response.statusCode == 207 || rejected.isNotEmpty,
    );
  }

  /// Mapeia [DioException] para [MessageSendException] com mensagem em PT-BR.
  MessageSendException _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    final body = e.response?.data;
    String? detail;
    if (body is Map && body['error'] is String) {
      detail = body['error'] as String;
    }
    switch (code) {
      case 413:
        return MessageSendException(
          message: detail ?? 'Imagem muito grande',
          statusCode: code,
        );
      case 415:
        return MessageSendException(
          message: detail ?? 'Tipo de imagem não suportado',
          statusCode: code,
        );
      case 429:
        return MessageSendException(
          message: detail ?? 'Muitos uploads — aguarde alguns minutos',
          statusCode: code,
        );
      case 401:
        return MessageSendException(
          message: 'Sessão expirada — refaça o login',
          statusCode: code,
        );
      case 400:
        return MessageSendException(
          message: detail ?? 'Payload inválido',
          statusCode: code,
        );
      case 404:
        return MessageSendException(
          message: detail ?? 'Team ou agente não encontrado',
          statusCode: code,
        );
      default:
        break;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const MessageSendException(
        message: 'Tempo esgotado — verifique sua conexão',
        statusCode: null,
      );
    }
    if (e.error is SocketException ||
        e.type == DioExceptionType.connectionError) {
      return const MessageSendException(
        message: 'Sem conexão com o servidor',
        statusCode: null,
      );
    }
    return MessageSendException(
      message: detail ?? 'Falha ao enviar: ${e.message ?? e.type.name}',
      statusCode: code,
    );
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
