import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../providers/teams_provider.dart';

class TeamCard extends ConsumerStatefulWidget {
  const TeamCard({super.key, required this.team, required this.onTap});

  final TeamModel team;
  final VoidCallback onTap;

  @override
  ConsumerState<TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends ConsumerState<TeamCard> {
  bool _actionLoading = false;

  AgentStatus get _status => switch (widget.team.status) {
        'active' => AgentStatus.active,
        'idle' => AgentStatus.idle,
        'error' => AgentStatus.error,
        _ => AgentStatus.offline,
      };

  bool get _isActive => widget.team.activeAgents > 0;

  Future<void> _confirmDelete() async {
    if (_actionLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonRed.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever,
                color: AppColors.neonRed, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Excluir team', style: AppTextStyles.heading2),
            ),
          ],
        ),
        content: Text(
          'Excluir "${widget.team.name}"? Esta ação não pode ser desfeita.',
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
            child: Text('Excluir',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.neonRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _actionLoading = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      await ref.read(teamsNotifierProvider.notifier).deleteTeam(widget.team.id);
      toast.success('Team "${widget.team.name}" excluído');
    } catch (e) {
      toast.error('Falha ao excluir team: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggle() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    final notifier = ref.read(teamsNotifierProvider.notifier);
    final toast = ref.read(toastProvider.notifier);
    final wasActive = _isActive;
    try {
      if (wasActive) {
        await notifier.stopTeam(widget.team.id);
      } else {
        await notifier.startTeam(widget.team.id);
      }
      toast.success(wasActive ? 'Team parado' : 'Team iniciado');
    } catch (e) {
      toast.error('Falha ao ${wasActive ? 'parar' : 'iniciar'} team: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final actionColor =
        _isActive ? AppColors.neonRed : AppColors.neonGreen;
    final actionIcon =
        _isActive ? Icons.stop_rounded : Icons.play_arrow_rounded;
    final actionTooltip = _isActive ? 'Parar team' : 'Iniciar team';

    return (GestureDetector(
      onTap: widget.onTap,
      onLongPress: _confirmDelete,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.neonPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.neonPurple.withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: AppColors.neonPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text(
                    team.description,
                    style: AppTextStyles.bodyMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(status: _status),
                      const SizedBox(width: 12),
                      Text(
                        '${team.activeAgents}/${team.agentCount} agentes',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                  if (team.agents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _AgentTags(agents: team.agents),
                  ],
                ],
              ),
            ),
            // Botão Start/Stop dinâmico
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                icon: _actionLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: actionColor,
                        ),
                      )
                    : Icon(actionIcon, color: actionColor),
                tooltip: actionTooltip,
                onPressed: _actionLoading ? null : _toggle,
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(
                  Icons.description_outlined,
                  color: AppColors.neonBlue,
                ),
                tooltip: 'Notas do team',
                onPressed: () =>
                    context.push('/team/${team.id}?tab=notes'),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    )).animate().fadeIn(duration: 220.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Tags horizontais dos agentes do team, com limite de 4 visíveis + "+N".
class _AgentTags extends StatelessWidget {
  const _AgentTags({required this.agents});

  final List<TeamAgentSummary> agents;

  static const _maxVisible = 4;

  @override
  Widget build(BuildContext context) {
    final visible = agents.take(_maxVisible).toList();
    final extra = agents.length - visible.length;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final a in visible) _AgentChip(name: a.name, active: a.active),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '+$extra',
              style: AppTextStyles.label.copyWith(fontSize: 10),
            ),
          ),
      ],
    );
  }
}

class _AgentChip extends StatelessWidget {
  const _AgentChip({required this.name, required this.active});

  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.neonGreen : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        name,
        style: AppTextStyles.label.copyWith(fontSize: 10, color: color),
      ),
    );
  }
}
