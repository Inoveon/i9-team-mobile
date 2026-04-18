import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/team_provider.dart';
import '../widgets/agent_panel.dart';
import '../widgets/message_input.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamNotifierProvider(teamId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: teamAsync.when(
          data: (t) => Text(t.name, style: AppTextStyles.heading1),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Text('Team', style: AppTextStyles.heading1),
        ),
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
        error: (e, _) => EmptyState(message: 'Erro: $e', icon: Icons.error_outline),
        data: (team) {
          final orchestrator = team.agents.where((a) => a.isOrchestrator).firstOrNull;
          final others = team.agents.where((a) => !a.isOrchestrator).toList();

          return Column(
            children: [
              if (orchestrator != null)
                AgentPanel(agent: orchestrator, expanded: true),
              if (others.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: others.length,
                    itemBuilder: (ctx, i) => SizedBox(
                      width: 280,
                      child: AgentPanel(agent: others[i]),
                    ),
                  ),
                ),
              const Spacer(),
              MessageInput(
                onSend: (msg) => ref.read(teamNotifierProvider(teamId).notifier).sendMessage(msg),
                sessionName: orchestrator?.sessionName,
                onImageUpload: (imageUrl) async {
                  // Após upload bem-sucedido, envia mensagem com link da imagem
                  final notifier = ref.read(teamNotifierProvider(teamId).notifier);
                  await notifier.sendMessage('Imagem compartilhada: $imageUrl');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
