import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.actionLabel,
  });

  final String message;
  final IconData icon;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: action,
              child: Text(actionLabel!, style: AppTextStyles.body.copyWith(color: AppColors.neonBlue)),
            ),
          ],
        ],
      ),
    );
  }
}
