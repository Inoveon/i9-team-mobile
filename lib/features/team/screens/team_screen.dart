import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../../notes/screens/notes_list_screen.dart';
import '../providers/team_provider.dart';
import '../providers/message_stream_provider.dart';
import '../providers/selected_agent_provider.dart';
import '../widgets/add_agent_dialog.dart';
import '../widgets/message_input.dart';
import '../widgets/chat_timeline_view.dart';

// Provider do agente selecionado (persistido em SharedPreferences por teamId
// via `selectedAgentIndexProvider`).

class TeamScreen extends ConsumerWidget {
  const TeamScreen({
    super.key,
    required this.teamId,
    this.initialTab,
    this.initialNote,
  });

  final String teamId;

  /// `agents` (default) | `notes`. Vindo do query param `?tab=notes`.
  final String? initialTab;

  /// Nome da nota a pré-abrir (ex: `notas/foo.md`), vindo do query param
  /// `?note=`. Só tem efeito quando `initialTab == 'notes'`.
  final String? initialNote;

  /// Abre dialog "Adicionar agente" + chama `POST /teams/:id/agents`.
  Future<void> _addAgent(
    BuildContext context,
    WidgetRef ref,
    List<AgentModel> existing,
  ) async {
    final result = await AddAgentDialog.show(
      context,
      existingNames: existing.map((a) => a.name).toSet(),
    );
    if (result == null) return;
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref
          .read(teamNotifierProvider(teamId).notifier)
          .addAgent(name: result.name, role: result.role);
      toast.success('Agente "${result.name}" adicionado');
    } catch (e) {
      toast.error('Falha ao adicionar: $e');
    }
  }

  /// Confirma remoção de um agente worker via `DELETE /teams/:id/agents/:aid`.
  /// Bloqueia remoção de orquestrador (role='orchestrator').
  Future<void> _confirmRemoveAgent(
    BuildContext context,
    WidgetRef ref,
    AgentModel agent,
  ) async {
    if (agent.isOrchestrator || agent.role == 'orchestrator') {
      ref
          .read(toastProvider.notifier)
          .warning('Não é possível remover o orquestrador');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonRed.withOpacity(0.4)),
        ),
        title: Text('Remover agente', style: AppTextStyles.heading2),
        content: Text(
          'Remover "${agent.name}" deste team?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remover',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.neonRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref
          .read(teamNotifierProvider(teamId).notifier)
          .removeAgent(agent.id);
      // Se removeu o selecionado, volta pro index 0
      final currentIdx = ref.read(selectedAgentIndexProvider(teamId));
      if (currentIdx > 0) {
        await ref
            .read(selectedAgentIndexProvider(teamId).notifier)
            .setIndex(0);
      }
      toast.success('Agente "${agent.name}" removido');
    } catch (e) {
      toast.error('Falha ao remover: $e');
    }
  }

  /// Confirma com o usuário e limpa o histórico do chat do agente selecionado.
  /// Mantém a conexão WebSocket intacta — só zera a lista de eventos em memória.
  Future<void> _confirmClearChat(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TeamDetailModel> teamAsync,
  ) async {
    final team = teamAsync.valueOrNull;
    if (team == null || team.agents.isEmpty) return;
    final idx = ref
        .read(selectedAgentIndexProvider(teamId))
        .clamp(0, team.agents.length - 1);
    final agent = team.agents[idx];
    final session = agent.sessionName;
    if (session == null || session.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
        ),
        title: Text('Limpar chat', style: AppTextStyles.heading2),
        content: Text(
          'Limpar histórico do chat com ${agent.name}? A conexão WebSocket permanece ativa e novas mensagens continuarão chegando.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Limpar',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.neonBlue,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(messageStreamProvider(session).notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamNotifierProvider(teamId));
    final selectedIndex = ref.watch(selectedAgentIndexProvider(teamId));

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == 'notes' ? 1 : 0,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        toolbarHeight: 52,
        title: teamAsync.when(
            data: (t) {
              final agentName = selectedIndex < t.agents.length
                  ? t.agents[selectedIndex].name
                  : '';
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.name, style: AppTextStyles.heading1),
                        if (agentName.isNotEmpty)
                          Text(
                            agentName,
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.neonBlue),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Text('Team', style: AppTextStyles.heading1),
          ),
          iconTheme: const IconThemeData(color: AppColors.neonBlue),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.neonBlue,
              ),
              tooltip: 'Limpar chat',
              onPressed: () => _confirmClearChat(context, ref, teamAsync),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.neonBlue,
            indicatorWeight: 2,
            labelColor: AppColors.neonBlue,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle:
                AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.label,
            tabs: const [
              Tab(
                icon: Icon(Icons.smart_toy_outlined, size: 16),
                text: 'Agentes',
              ),
              Tab(
                icon: Icon(Icons.description_outlined, size: 16),
                text: 'Notas',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAgentsTab(context, ref, teamAsync, selectedIndex),
            NotesListScreen(
              teamId: teamId,
              embedded: true,
              initialNoteName: initialNote,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TeamDetailModel> teamAsync,
    int selectedIndex,
  ) {
    return teamAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neonBlue)),
          error: (e, _) =>
              EmptyState(message: 'Erro: $e', icon: Icons.error_outline),
          data: (team) {
            final allAgents = team.agents;
            if (allAgents.isEmpty) {
              return const EmptyState(
                message: 'Nenhum agente encontrado.',
                icon: Icons.smart_toy_outlined,
              );
            }
            final idx = selectedIndex.clamp(0, allAgents.length - 1);
            final selectedAgent = allAgents[idx];
            final activeCount =
                allAgents.where((a) => a.status == 'active').length;

            return Column(
              children: [
                // 🔹 Contador X/Y ativos + botão "+" adicionar agente
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? AppColors.neonGreen
                              : AppColors.textMuted,
                          shape: BoxShape.circle,
                          boxShadow: activeCount > 0
                              ? [
                                  BoxShadow(
                                    color:
                                        AppColors.neonGreen.withOpacity(0.5),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$activeCount/${allAgents.length} agentes ativos',
                        style: AppTextStyles.label.copyWith(
                          color: activeCount > 0
                              ? AppColors.neonGreen
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 🔹 Chips de seleção de agente
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 10, 24, 10),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      ...List.generate(allAgents.length, (i) {
                      final agent = allAgents[i];
                      final isSelected = idx == i;
                      return GestureDetector(
                        onTap: () => ref
                            .read(selectedAgentIndexProvider(teamId).notifier)
                            .setIndex(i),
                        onLongPress: () =>
                            _confirmRemoveAgent(context, ref, agent),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonBlue.withOpacity(0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color:
                                  isSelected ? AppColors.neonBlue : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                agent.isOrchestrator
                                    ? Icons.hub_outlined
                                    : Icons.smart_toy_outlined,
                                color: isSelected
                                    ? AppColors.neonBlue
                                    : AppColors.border,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                agent.name,
                                style: AppTextStyles.label.copyWith(
                                  color: isSelected
                                      ? AppColors.neonBlue
                                      : const Color(0xFF8892a4),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (agent.status == 'active') ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.neonGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                      // Chip "+" adicionar agente
                      GestureDetector(
                        onTap: () => _addAgent(context, ref, allAgents),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.neonGreen.withOpacity(0.08),
                            border: Border.all(
                              color: AppColors.neonGreen.withOpacity(0.4),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  color: AppColors.neonGreen, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'agente',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.neonGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0x1A00D4FF)),

                // 🔹 Chat do agente selecionado (única view — terminal removido)
                Expanded(
                  child: (selectedAgent.sessionName != null &&
                          selectedAgent.sessionName!.isNotEmpty)
                      ? ChatTimelineView(
                          key: ValueKey('chat_${selectedAgent.id}'),
                          session: selectedAgent.sessionName!,
                        )
                      : const EmptyState(
                          message:
                              'Agente sem sessão tmux ativa.\nInicie o team para conectar ao stream.',
                          icon: Icons.link_off,
                        ),
                ),
                SafeArea(
                  top: false,
                  child: MessageInput(
                    onSend: (msg) async {
                      // REST é suficiente — backend resolve via tmux send-keys.
                      try {
                        await ref
                            .read(teamNotifierProvider(teamId).notifier)
                            .sendMessage(msg, agentId: selectedAgent.id);
                      } catch (e) {
                        ref
                            .read(toastProvider.notifier)
                            .error('Falha ao enviar: $e');
                      }
                    },
                    sessionName: selectedAgent.sessionName,
                    onImageUpload: (imageUrl) async {
                      final notifier = ref
                          .read(teamNotifierProvider(teamId).notifier);
                      await notifier.sendMessage(
                        'Imagem compartilhada: $imageUrl',
                        agentId: selectedAgent.id,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}

