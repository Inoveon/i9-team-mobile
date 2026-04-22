import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Resultado do wizard: `name` = "projeto/team" + lista de agentes.
typedef NewTeamResult = ({
  String name,
  String? description,
  List<({String name, String role})> agents,
});

/// Wizard "Novo team" — coleta projeto + team + lista dinâmica de agentes.
/// Valida regex + exatamente 1 orchestrator.
class NewTeamDialog extends StatefulWidget {
  const NewTeamDialog({super.key});

  static Future<NewTeamResult?> show(BuildContext context) {
    return showDialog<NewTeamResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewTeamDialog(),
    );
  }

  @override
  State<NewTeamDialog> createState() => _NewTeamDialogState();
}

class _NewTeamDialogState extends State<NewTeamDialog> {
  final _projectController = TextEditingController();
  final _teamController = TextEditingController();
  final _descController = TextEditingController();
  final List<_AgentDraft> _agents = [_AgentDraft(role: 'orchestrator')];
  String? _error;

  static final _validSlug = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

  @override
  void dispose() {
    _projectController.dispose();
    _teamController.dispose();
    _descController.dispose();
    for (final a in _agents) {
      a.dispose();
    }
    super.dispose();
  }

  void _addAgentRow() {
    setState(() => _agents.add(_AgentDraft(role: 'worker')));
  }

  void _removeAgentRow(int i) {
    setState(() {
      _agents[i].dispose();
      _agents.removeAt(i);
    });
  }

  void _submit() {
    final project = _projectController.text.trim();
    final team = _teamController.text.trim();
    if (project.isEmpty || team.isEmpty) {
      setState(() => _error = 'Projeto e team são obrigatórios');
      return;
    }
    if (!_validSlug.hasMatch(project) || !_validSlug.hasMatch(team)) {
      setState(() =>
          _error = 'Use letras minúsculas, números, - ou _ em projeto e team');
      return;
    }
    if (_agents.isEmpty) {
      setState(() => _error = 'Adicione ao menos 1 agente');
      return;
    }

    // Extrai nomes + valida
    final built = <({String name, String role})>[];
    final seen = <String>{};
    for (var i = 0; i < _agents.length; i++) {
      final n = _agents[i].name.trim();
      if (n.isEmpty) {
        setState(() => _error = 'Agente ${i + 1}: nome vazio');
        return;
      }
      if (!_validSlug.hasMatch(n)) {
        setState(() => _error = 'Agente ${i + 1}: nome inválido');
        return;
      }
      if (!seen.add(n)) {
        setState(() => _error = 'Nome de agente duplicado: "$n"');
        return;
      }
      built.add((name: n, role: _agents[i].role));
    }
    final orchestrators =
        built.where((a) => a.role == 'orchestrator').length;
    if (orchestrators != 1) {
      setState(() => _error =
          'Exatamente 1 agente deve ter role "orchestrator" (atual: $orchestrators)');
      return;
    }

    Navigator.of(context).pop((
      name: '$project/$team',
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      agents: built,
    ));
  }

  InputDecoration _dec(String label, {String? hint, String? err}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTextStyles.bodyMuted,
        errorText: err,
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.neonBlue),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      title: Text('Novo team', style: AppTextStyles.heading2),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _projectController,
                      style: AppTextStyles.body,
                      cursorColor: AppColors.neonBlue,
                      decoration: _dec('Projeto', hint: 'i9-team'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _teamController,
                      style: AppTextStyles.body,
                      cursorColor: AppColors.neonBlue,
                      decoration: _dec('Team', hint: 'dev'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                style: AppTextStyles.body,
                cursorColor: AppColors.neonBlue,
                decoration: _dec('Descrição (opcional)'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Agentes', style: AppTextStyles.heading2.copyWith(fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addAgentRow,
                    icon: const Icon(Icons.add,
                        color: AppColors.neonGreen, size: 16),
                    label: Text('agente',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.neonGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < _agents.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _agents[i].controller,
                          style: AppTextStyles.body,
                          cursorColor: AppColors.neonBlue,
                          decoration: _dec('nome', hint: 'dev-backend'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _agents[i].role,
                          isDense: true,
                          dropdownColor: AppColors.surface,
                          style: AppTextStyles.body,
                          decoration: _dec('role'),
                          items: const [
                            DropdownMenuItem(
                                value: 'worker', child: Text('worker')),
                            DropdownMenuItem(
                                value: 'orchestrator',
                                child: Text('orchestrator')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _agents[i].role = v);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.neonRed, size: 20),
                        onPressed: _agents.length > 1
                            ? () => _removeAgentRow(i)
                            : null,
                      ),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.neonRed)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Criar',
              style: AppTextStyles.body.copyWith(
                color: AppColors.neonBlue,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
}

class _AgentDraft {
  _AgentDraft({required this.role}) : controller = TextEditingController();
  final TextEditingController controller;
  String role;
  String get name => controller.text;
  void dispose() => controller.dispose();
}
