import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Card exibido quando o agente entra em Plan Mode (ExitPlanMode tool_call).
/// Apresenta dois botões: Aprovar e Rejeitar o plano proposto.
class PlanApprovalCard extends StatefulWidget {
  const PlanApprovalCard({
    super.key,
    required this.onApprove,
    required this.onReject,
  });

  /// Chamado quando o usuário aprova o plano (envia "sim" ao agente).
  final Future<void> Function() onApprove;

  /// Chamado quando o usuário rejeita o plano (envia "não" ao agente).
  final Future<void> Function() onReject;

  @override
  State<PlanApprovalCard> createState() => _PlanApprovalCardState();
}

class _PlanApprovalCardState extends State<PlanApprovalCard> {
  bool _loading = false;

  Future<void> _handle(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neonYellow.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.neonYellow.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: AppColors.neonYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Agente aguarda aprovação do plano',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.neonYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: Color(0x26FFD700),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.neonYellow,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Aprovar',
                          icon: Icons.check_circle_outline,
                          color: AppColors.neonGreen,
                          onTap: () => _handle(widget.onApprove),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          label: 'Rejeitar',
                          icon: Icons.cancel_outlined,
                          color: AppColors.neonRed,
                          onTap: () => _handle(widget.onReject),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
