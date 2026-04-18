import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'glass_container.dart';

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.neonBlue;
    return GestureDetector(
      onTap: onPressed,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.body.copyWith(color: c, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
