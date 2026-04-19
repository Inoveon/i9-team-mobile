import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Chip cinza pequeno para mensagens de sistema ("Crunched for 2s", etc.)
class SystemBadge extends StatelessWidget {
  const SystemBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x1A8892A4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.4)),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
