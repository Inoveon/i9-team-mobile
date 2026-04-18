import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/teams_provider.dart';

class TeamCard extends StatelessWidget {
  const TeamCard({super.key, required this.team, required this.onTap});

  final TeamModel team;
  final VoidCallback onTap;

  AgentStatus get _status => switch (team.status) {
        'active' => AgentStatus.active,
        'idle' => AgentStatus.idle,
        'error' => AgentStatus.error,
        _ => AgentStatus.offline,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                border: Border.all(color: AppColors.neonPurple.withOpacity(0.4)),
              ),
              child: const Icon(Icons.groups_outlined, color: AppColors.neonPurple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text(team.description, style: AppTextStyles.bodyMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
