import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o índice do agente selecionado por team, persistindo em
/// SharedPreferences sob a chave `team:<teamId>:lastAgentIndex`.
///
/// - Valor inicial síncrono: `0`
/// - Restauração do SharedPreferences: assíncrona no construtor
/// - Persistência: a cada mudança (fire-and-forget, sem debounce — o usuário
///   troca de chip poucas vezes por minuto)
class SelectedAgentNotifier extends StateNotifier<int> {
  SelectedAgentNotifier(this._teamId) : super(0) {
    _restore();
  }

  final String _teamId;

  String get _key => 'team:$_teamId:lastAgentIndex';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_key);
      if (idx != null && idx >= 0) state = idx;
    } catch (e) {
      debugPrint('[selected_agent] restore error: $e');
    }
  }

  Future<void> setIndex(int index) async {
    if (state == index) return;
    state = index;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, index);
    } catch (e) {
      debugPrint('[selected_agent] save error: $e');
    }
  }
}

/// Family por teamId — cada team lembra o próprio último agente.
final selectedAgentIndexProvider =
    StateNotifierProvider.family<SelectedAgentNotifier, int, String>(
  (ref, teamId) => SelectedAgentNotifier(teamId),
);
