import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart' show StatusBadge, AgentStatus;
import '../../team/widgets/chat_timeline_view.dart';
import '../../team/widgets/agent_panel.dart';
import '../providers/agent_detail_provider.dart';
import '../widgets/plan_approval_card.dart';

/// Tela dedicada a um agente específico.
///
/// Exibe:
/// - Header com nome, role e status badge
/// - [ChatTimelineView] com todo o histórico de mensagens tipadas
/// - [PlanApprovalCard] quando o agente entra em Plan Mode
/// - Terminal raw (aba) com o output tmux
class AgentScreen extends ConsumerWidget {
  const AgentScreen({
    super.key,
    required this.teamId,
    required this.agentId,
  });

  final String teamId;
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (teamId: teamId, agentId: agentId);
    final detail = ref.watch(agentDetailProvider(key));

    final agent = detail.agent;
    final session = agent?.sessionName ?? agentId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          toolbarHeight: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.neonBlue, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: agent == null
              ? Text('Agente', style: AppTextStyles.heading1)
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(agent.name, style: AppTextStyles.heading1),
                          Text(
                            agent.role.isNotEmpty ? agent.role : 'agent',
                            style: AppTextStyles.label,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: _parseStatus(agent.status)),
                  ],
                ),
          bottom: const TabBar(
            indicatorColor: AppColors.neonBlue,
            indicatorWeight: 2,
            labelColor: AppColors.neonBlue,
            unselectedLabelColor: AppColors.border,
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 16), text: 'Chat'),
              Tab(icon: Icon(Icons.terminal, size: 16), text: 'Terminal'),
            ],
          ),
        ),
        body: agent == null && detail.error != null
            ? EmptyState(
                message: 'Agente não encontrado.\n${detail.error}',
                icon: Icons.error_outline,
              )
            : Column(
                children: [
                  // Card de aprovação de plano — aparece acima do conteúdo
                  if (detail.isInPlanMode)
                    PlanApprovalCard(
                      onApprove: () => _sendMessage(ref, 'sim'),
                      onReject: () => _sendMessage(ref, 'não'),
                    ),

                  // Conteúdo principal por aba
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Aba Chat — timeline de mensagens tipadas
                        ChatTimelineView(session: session),

                        // Aba Terminal — output raw do agente
                        agent == null
                            ? const EmptyState(
                                message: 'Carregando...',
                                icon: Icons.hourglass_empty,
                              )
                            : AgentPanel(
                                agent: agent,
                                expanded: true,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static AgentStatus _parseStatus(String s) => switch (s) {
        'active' => AgentStatus.active,
        'idle' => AgentStatus.idle,
        'error' => AgentStatus.error,
        _ => AgentStatus.offline,
      };

  Future<void> _sendMessage(WidgetRef ref, String message) async {
    try {
      await ApiService.sendMessage(teamId, message);
    } catch (e) {
      debugPrint('AgentScreen._sendMessage error: $e');
    }
  }
}
