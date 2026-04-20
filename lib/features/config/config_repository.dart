import 'dart:convert';

import '../../core/network/api_client.dart';

/// Cliente HTTP para `/teams/config` + `/teams/sync`.
class ConfigRepository {
  ConfigRepository._();

  /// GET /teams/config — lê teams.json cru. Retorna o JSON pretty-printed.
  static Future<String> getConfig() async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.get<dynamic>('/teams/config');
    // Backend devolve o objeto parseado. Serializa com indentação de 2 espaços
    // pra matchar o que o frontend `/config` exibe.
    return const JsonEncoder.withIndent('  ').convert(resp.data);
  }

  /// PUT /teams/config — sobrescreve teams.json (atômico) + resync.
  /// Retorna o mapa `{ok, path, synced}` do backend.
  static Future<Map<String, dynamic>> saveConfig(String jsonText) async {
    final parsed = jsonDecode(jsonText);
    final dio = await ApiClient.getInstance();
    final resp = await dio.put<dynamic>('/teams/config', data: parsed);
    final body = resp.data;
    return body is Map
        ? body.cast<String, dynamic>()
        : <String, dynamic>{'ok': true};
  }

  /// POST /teams/sync — força resync teams.json → DB sem alterar o arquivo.
  static Future<Map<String, dynamic>> sync() async {
    final dio = await ApiClient.getInstance();
    final resp = await dio.post<dynamic>('/teams/sync');
    final body = resp.data;
    return body is Map
        ? body.cast<String, dynamic>()
        : <String, dynamic>{'ok': true};
  }
}
