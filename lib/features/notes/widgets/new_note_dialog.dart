import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dialog para criar uma nova nota — coleta o nome (sem extensão) e opcional
/// template inicial. O caller decide o que fazer com o resultado.
class NewNoteDialog extends StatefulWidget {
  const NewNoteDialog({super.key});

  /// Retorna o nome válido (com `.md`) ou null se cancelado.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const NewNoteDialog(),
    );
  }

  @override
  State<NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<NewNoteDialog> {
  final _controller = TextEditingController();
  String? _error;

  // Regex simples: alphanum, hífen, underscore, barra, ponto. Sem espaços.
  static final _validName = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_\-./]*$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Nome obrigatório');
      return;
    }
    if (!_validName.hasMatch(raw)) {
      setState(() => _error = 'Use apenas letras, números, _ - . / e sem espaços');
      return;
    }
    final name = raw.endsWith('.md') ? raw : '$raw.md';
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      title: Text('Nova nota', style: AppTextStyles.heading2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTextStyles.body,
            cursorColor: AppColors.neonBlue,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'minha-nota',
              hintStyle: AppTextStyles.bodyMuted,
              errorText: _error,
              helperText: 'Extensão .md é adicionada se faltar',
              helperStyle: AppTextStyles.label,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.neonBlue.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.neonBlue),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.neonRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.neonRed),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Criar',
            style: AppTextStyles.body.copyWith(
              color: AppColors.neonBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
