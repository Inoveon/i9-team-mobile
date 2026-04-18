import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum AgentStatus { active, idle, error, offline }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final AgentStatus status;

  Color get _color => switch (status) {
        AgentStatus.active => AppColors.neonGreen,
        AgentStatus.idle => AppColors.neonYellow,
        AgentStatus.error => AppColors.neonRed,
        AgentStatus.offline => AppColors.textMuted,
      };

  String get _label => switch (status) {
        AgentStatus.active => 'ATIVO',
        AgentStatus.idle => 'OCIOSO',
        AgentStatus.error => 'ERRO',
        AgentStatus.offline => 'OFFLINE',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(_label, style: AppTextStyles.label.copyWith(color: _color)),
        ],
      ),
    );
  }
}
