import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MessageInput extends StatefulWidget {
  const MessageInput({super.key, required this.onSend});

  final void Function(String message) onSend;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _hasText = _controller.text.trim().isNotEmpty));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    widget.onSend(msg);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.body,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Mensagem para o orquestrador...',
                hintStyle: AppTextStyles.bodyMuted,
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedOpacity(
            opacity: _hasText ? 1 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _hasText ? _send : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
                ),
                child: const Icon(Icons.send_rounded, color: AppColors.neonBlue, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
