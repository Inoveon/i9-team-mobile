import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_event.dart';
import '../providers/message_stream_provider.dart';
import '../providers/optimistic_messages_provider.dart';
import '../widgets/user_bubble.dart';
import '../widgets/claude_bubble.dart';
import '../widgets/tool_call_card.dart';
import '../widgets/thinking_widget.dart';
import '../widgets/system_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Timeline de mensagens tipadas. Ouve [messageStreamProvider] para a sessão
/// dada e renderiza cada [MessageEvent] com o widget adequado.
///
/// Mapeia automaticamente tool_call com seu tool_result correspondente pelo [id].
class ChatTimelineView extends ConsumerStatefulWidget {
  const ChatTimelineView({
    super.key,
    required this.session,
  });

  final String session;

  @override
  ConsumerState<ChatTimelineView> createState() => _ChatTimelineViewState();
}

class _ChatTimelineViewState extends ConsumerState<ChatTimelineView> {
  final _scrollController = ScrollController();
  int _lastSeenEventCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Constrói a lista de widgets mesclando tool_call com tool_result pelo id.
  List<Widget> _buildWidgets(List<MessageEvent> events) {
    // Pré-indexa tool_results pelo id para lookup O(1)
    final resultById = <String, MessageEvent>{};
    for (final e in events) {
      if (e.type == MessageEventType.toolResult && e.toolId != null) {
        resultById[e.toolId!] = e;
      }
    }

    final widgets = <Widget>[];
    final skippedIds = <String>{};

    for (final event in events) {
      // tool_result já anexado ao tool_call — pular renderização separada
      if (event.type == MessageEventType.toolResult) continue;

      switch (event.type) {
        case MessageEventType.userInput:
          if (event.text != null && event.text!.isNotEmpty) {
            widgets.add(UserBubble(text: event.text!));
          }

        case MessageEventType.claudeText:
          if (event.text != null && event.text!.isNotEmpty) {
            widgets.add(ClaudeBubble(text: event.text!));
          }

        case MessageEventType.toolCall:
          final result = event.toolId != null ? resultById[event.toolId] : null;
          widgets.add(ToolCallCard(
            toolName: event.toolName ?? 'Tool',
            args: event.toolArgs,
            result: result?.toolContent,
            toolId: event.toolId,
          ));

        case MessageEventType.thinking:
          widgets.add(ThinkingWidget(text: event.text));

        case MessageEventType.system:
          if (event.text != null && event.text!.isNotEmpty) {
            widgets.add(SystemBadge(text: event.text!));
          }

        case MessageEventType.interactiveMenu:
          // Menus interativos já tratados pela _AgentChatView — aqui exibe como badge
          widgets.add(SystemBadge(
            text: '📋 ${event.menuTitle ?? 'Menu interativo'}',
          ));

        // Já tratado acima
        case MessageEventType.toolResult:
          break;
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageStreamProvider(widget.session));
    final optimistic = ref.watch(optimisticMessagesProvider(widget.session));

    // Reconciliação: quando novos user_input aparecem, remove otimistas com
    // texto correspondente.
    if (state.events.length > _lastSeenEventCount) {
      final newEvents = state.events.sublist(_lastSeenEventCount);
      _lastSeenEventCount = state.events.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier =
            ref.read(optimisticMessagesProvider(widget.session).notifier);
        for (final e in newEvents) {
          if (e.type == MessageEventType.userInput && e.text != null) {
            notifier.clearIfMatches(e.text!);
          }
        }
      });
    }

    // Auto-scroll quando novos eventos chegam (ou otimistas)
    if (state.events.isNotEmpty || optimistic.isNotEmpty) _scrollToBottom();

    if (!state.connected && state.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.neonBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text('Conectando ao stream...', style: AppTextStyles.bodyMuted),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text('Erro: ${state.error}', style: AppTextStyles.bodyMuted),
      );
    }

    if (state.events.isEmpty && optimistic.isEmpty) {
      return Center(
        child: Text(
          'Aguardando mensagens...',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }

    final widgets = _buildWidgets(state.events);
    // Anexa otimistas ao final — aparecerão após a última msg do stream.
    for (final m in optimistic) {
      widgets.add(UserBubble(
        text: m.text,
        attachments: m.attachments,
        pending: true,
      ));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widgets.length,
      itemBuilder: (_, i) => widgets[i],
    );
  }
}
