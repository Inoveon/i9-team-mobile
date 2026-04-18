import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/output_parser.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ParsedMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isAssistant) {
      // Assistente: texto full-width, sem bubble, fundo transparente
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          message.text,
          style: AppTextStyles.body.copyWith(
            color: const Color(0xFFe2e8f0),
            height: 1.65,
          ),
        ),
      );
    }

    // Usuário: bubble direita, neon azul
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 56, right: 12, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.neonBlue.withOpacity(0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
        ),
        child: Text(
          message.text,
          style: AppTextStyles.body.copyWith(
            color: AppColors.neonBlue,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
