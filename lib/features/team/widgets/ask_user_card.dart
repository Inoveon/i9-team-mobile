import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_model.dart';

/// Card interativo estilo AskUserQuestion — igual ao padrão do Claude app.
class AskUserCard extends StatelessWidget {
  const AskUserCard({
    super.key,
    required this.menu,
    required this.onSelect,
  });

  final InteractiveMenu menu;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, color: AppColors.neonBlue, size: 18),
                const SizedBox(width: 8),
                Text('Escolha uma opção', style: AppTextStyles.label.copyWith(color: AppColors.neonBlue)),
              ],
            ),
          ),
          const Divider(color: Color(0x1A00D4FF), height: 1),
          // Opções
          ...menu.options.asMap().entries.map((entry) {
            final opt = entry.value;
            final isCurrent = opt.current || opt.index == menu.currentIndex;

            return InkWell(
              borderRadius: entry.key == menu.options.length - 1
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : BorderRadius.zero,
              onTap: () => onSelect(opt.index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.neonBlue.withOpacity(0.1) : Colors.transparent,
                  border: entry.key < menu.options.length - 1
                      ? const Border(bottom: BorderSide(color: Color(0x1A00D4FF)))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? AppColors.neonBlue : AppColors.border,
                          width: 1.5,
                        ),
                        color: isCurrent ? AppColors.neonBlue.withOpacity(0.2) : Colors.transparent,
                      ),
                      child: isCurrent
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonBlue,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt.label,
                        style: AppTextStyles.body.copyWith(
                          color: isCurrent ? AppColors.neonBlue : const Color(0xFFe2e8f0),
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
