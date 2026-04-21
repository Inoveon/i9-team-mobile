import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/user_bubble.dart';

/// Mensagem enviada otimisticamente — renderizada na timeline antes do eco do
/// backend chegar via WebSocket (`user_input`).
class OptimisticMessage {
  const OptimisticMessage({
    required this.id,
    required this.text,
    required this.attachments,
    required this.sentAt,
  });

  final String id;
  final String text;
  final List<BubbleAttachment> attachments;
  final DateTime sentAt;

  OptimisticMessage withFailureFlags(Set<String> rejectedRemoteIds) {
    if (rejectedRemoteIds.isEmpty) return this;
    return OptimisticMessage(
      id: id,
      text: text,
      sentAt: sentAt,
      attachments: [
        for (final a in attachments)
          if (a.remoteUrl != null &&
              rejectedRemoteIds.any((rid) => a.remoteUrl!.contains(rid)))
            BubbleAttachment(
              localPath: a.localPath,
              localBytes: a.localBytes,
              remoteUrl: a.remoteUrl,
              filename: a.filename,
              failed: true,
            )
          else
            a,
      ],
    );
  }
}

/// Gerencia mensagens otimistas por `sessionName` (cada agente tem sua).
///
/// Ciclo de vida:
/// 1. `add(text, attachments)` — inclui na lista imediatamente após o user
///    tocar em Enviar. A UI exibe com `pending: true`.
/// 2. O `ChatTimelineView` observa `messageStreamProvider` e, sempre que um
///    evento `user_input` com texto correspondente chegar, chama
///    `clearIfMatches(text)` para remover a otimista.
/// 3. Fallback: cada entrada tem TTL de [_ttl] — sumiria sozinha depois disso
///    mesmo sem eco. Previne bolhas fantasma se o backend abortar o envio.
class OptimisticMessagesNotifier
    extends StateNotifier<List<OptimisticMessage>> {
  OptimisticMessagesNotifier() : super(const []);

  static const _ttl = Duration(seconds: 12);

  final Map<String, Timer> _timers = {};
  int _counter = 0;

  String add({
    required String text,
    List<BubbleAttachment> attachments = const [],
  }) {
    final id = 'opt_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    final msg = OptimisticMessage(
      id: id,
      text: text,
      attachments: attachments,
      sentAt: DateTime.now(),
    );
    state = [...state, msg];

    _timers[id] = Timer(_ttl, () => _remove(id));
    return id;
  }

  /// Marca anexos rejeitados por UUID do backend para render com borda vermelha
  /// até o eco remover a otimista (ou TTL expirar).
  void markRejected(String id, Set<String> rejectedRemoteIds) {
    state = [
      for (final m in state)
        if (m.id == id) m.withFailureFlags(rejectedRemoteIds) else m,
    ];
  }

  /// Remove a otimista mais antiga cujo [text] bate com o eco `user_input`.
  /// Se [text] for vazio, tenta remover a otimista mais antiga com anexos.
  void clearIfMatches(String text) {
    final trimmed = text.trim();
    final idx = state.indexWhere((m) {
      if (trimmed.isEmpty) return m.attachments.isNotEmpty;
      // Backend injeta `@<path>` após texto no tmux, mas o user_input que ele
      // retorna tipicamente só reflete o que o Claude Code viu. Matching por
      // prefixo do texto é suficiente.
      final t = m.text.trim();
      if (t.isEmpty) return false;
      return trimmed.contains(t) || t.contains(trimmed);
    });
    if (idx < 0) return;
    final id = state[idx].id;
    _remove(id);
  }

  void _remove(String id) {
    _timers.remove(id)?.cancel();
    state = state.where((m) => m.id != id).toList();
  }

  /// Limpa todas — usado em `clear chat` na AppBar.
  void clearAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    state = const [];
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// Parametrizado por `sessionName` — cada agente tem sua lista otimista
/// isolada (e sua timeline no `ChatTimelineView`).
final optimisticMessagesProvider = StateNotifierProvider.family<
    OptimisticMessagesNotifier, List<OptimisticMessage>, String>(
  (ref, session) => OptimisticMessagesNotifier(),
);
