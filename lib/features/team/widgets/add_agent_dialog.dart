import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dialog simples com 2 campos (nome + role) para adicionar agente.
class AddAgentDialog extends StatefulWidget {
  const AddAgentDialog({super.key, required this.existingNames});

  /// Nomes já usados no team — rejeita duplicatas.
  final Set<String> existingNames;

  /// Retorna `(name, role)` ou null se cancelado.
  static Future<({String name, String role})?> show(
    BuildContext context, {
    required Set<String> existingNames,
  }) {
    return showDialog<({String name, String role})>(
      context: context,
      builder: (_) => AddAgentDialog(existingNames: existingNames),
    );
  }

  @override
  State<AddAgentDialog> createState() => _AddAgentDialogState();
}

class _AddAgentDialogState extends State<AddAgentDialog> {
  final _controller = TextEditingController();
  String _role = 'worker';
  String? _error;

  static final _validName = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

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
      setState(() => _error =
          'Use letras minúsculas, números, - ou _ (começar com letra/número)');
      return;
    }
    if (widget.existingNames.contains(raw)) {
      setState(() => _error = 'Já existe um agente com esse nome');
      return;
    }
    Navigator.of(context).pop((name: raw, role: _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      title: Text('Adicionar agente', style: AppTextStyles.heading2),
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
              labelText: 'Nome',
              hintText: 'dev-backend',
              hintStyle: AppTextStyles.bodyMuted,
              errorText: _error,
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
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _role,
            dropdownColor: AppColors.surface,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              labelText: 'Role',
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
            ),
            items: const [
              DropdownMenuItem(value: 'worker', child: Text('worker')),
              DropdownMenuItem(
                  value: 'orchestrator', child: Text('orchestrator')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Adicionar',
              style: AppTextStyles.body.copyWith(
                color: AppColors.neonBlue,
                fontWeight: FontWeight.w600,
              )),
        ),
      ],
    );
  }
}
