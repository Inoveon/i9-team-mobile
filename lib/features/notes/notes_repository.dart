import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models/note.dart';

/// Cliente HTTP para o endpoint /teams/:id/notes do backend.
///
/// Os métodos lançam [DioException] em erros de rede e [NoteConflict]
/// quando o servidor responde 409 em um PUT com etag desatualizado.
class NotesRepository {
  NotesRepository(this.teamId);

  final String teamId;

  String get _base => '/teams/$teamId/notes';

  /// Codifica o nome permitindo que subpastas viajem como /-encoded.
  String _encodeName(String name) {
    return name
        .split('/')
        .map((seg) => Uri.encodeComponent(seg))
        .join('/');
  }

  /// GET /teams/:id/notes — lista resumida ordenada DESC por updatedAt.
  Future<List<NoteSummary>> list() async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.get<dynamic>(_base);
    final raw = resp.data;
    final list = raw is List
        ? raw
        : (raw is Map && raw['notes'] is List ? raw['notes'] as List : const []);
    return list
        .whereType<Map>()
        .map((m) => NoteSummary.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// GET /teams/:id/notes/:name — lê a nota completa.
  Future<Note> read(String name) async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.get<dynamic>('$_base/${_encodeName(name)}');
    final data = resp.data as Map<String, dynamic>;
    return Note.fromJson(data);
  }

  /// PUT /teams/:id/notes/:name — salva conteúdo.
  ///
  /// Se [expectedEtag] é fornecido e o backend responde 409, lança
  /// [NoteConflict] com o conteúdo atual do servidor pra resolução.
  Future<Note> save(
    String name,
    String content, {
    String? expectedEtag,
  }) async {
    final dio = await ApiClient.getInstance();
    try {
      final resp = await dio.put<dynamic>(
        '$_base/${_encodeName(name)}',
        data: {
          'content': content,
          if (expectedEtag != null && expectedEtag.isNotEmpty)
            'expectedEtag': expectedEtag,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      return Note(
        name: name,
        content: content,
        size: content.length,
        updatedAt: _parseDate(data['savedAt']),
        etag: (data['etag'] as String?) ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data is Map) {
        final body = (e.response!.data as Map).cast<String, dynamic>();
        throw NoteConflict(
          currentEtag: (body['currentEtag'] as String?) ?? '',
          currentContent: (body['currentContent'] as String?) ?? '',
        );
      }
      rethrow;
    }
  }

  /// POST /teams/:id/notes — cria nota nova.
  Future<Note> create(String name, String content) async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.post<dynamic>(
      _base,
      data: {'name': name, 'content': content},
    );
    final status = resp.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      final data = resp.data is Map
          ? (resp.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      return Note(
        name: (data['name'] as String?) ?? name,
        content: content,
        size: content.length,
        updatedAt: _parseDate(data['savedAt'] ?? data['updatedAt']),
        etag: (data['etag'] as String?) ?? '',
      );
    }
    throw DioException(
      requestOptions: RequestOptions(path: _base),
      response: resp,
      error: 'Falha ao criar nota',
    );
  }

  /// DELETE /teams/:id/notes/:name.
  Future<void> delete(String name) async {
    final dio = await ApiClient.getInstance();
    await dio.delete<dynamic>('$_base/${_encodeName(name)}');
  }
}

DateTime _parseDate(dynamic v) {
  if (v is String) {
    return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}
