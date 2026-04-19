import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Bolha de resposta do Claude — alinhada à esquerda, glass escuro + markdown.
class ClaudeBubble extends StatelessWidget {
  const ClaudeBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 56, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.15)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: MarkdownBody(
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: AppTextStyles.body,
            h1: AppTextStyles.heading1,
            h2: AppTextStyles.heading2,
            h3: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            code: AppTextStyles.body.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.neonGreen,
              backgroundColor: const Color(0x1A00FF88),
            ),
            codeblockDecoration: BoxDecoration(
              color: const Color(0x0D00FF88),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.neonGreen.withOpacity(0.2)),
            ),
            blockquote: AppTextStyles.bodyMuted.copyWith(
              fontStyle: FontStyle.italic,
            ),
            tableBody: AppTextStyles.body,
            tableHead: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
