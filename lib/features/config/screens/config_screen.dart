import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../config_repository.dart';
import '../providers/config_provider.dart';

/// Editor do `teams.json` — espelha o `/config` do frontend.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _controller = TextEditingController();
  String _original = '';
  String? _parseError;
  bool _saving = false;
  bool _syncing = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _parseError == null;
  bool get _isDirty => _controller.text != _original;

  void _validate(String raw) {
    if (raw.trim().isEmpty) {
      setState(() => _parseError = 'JSON vazio');
      return;
    }
    try {
      jsonDecode(raw);
      if (_parseError != null) setState(() => _parseError = null);
    } catch (e) {
      setState(() => _parseError = e.toString().replaceFirst('FormatException: ', ''));
    }
  }

  Future<void> _confirmAndSave() async {
    if (!_isValid || _saving) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonYellow.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.neonYellow, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Salvar teams.json', style: AppTextStyles.heading2),
            ),
          ],
        ),
        content: Text(
          'Isso sobrescreve o teams.json no servidor e ressincroniza o DB. Continuar?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Salvar',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.neonYellow,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      final result = await ConfigRepository.saveConfig(_controller.text);
      final synced = result['synced'];
      toast.success(
        synced is Map
            ? 'teams.json salvo — ${synced['teams'] ?? '?'} teams sincronizados'
            : 'teams.json salvo',
      );
      if (mounted) setState(() => _original = _controller.text);
    } catch (e) {
      toast.error('Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncOnly() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      final result = await ConfigRepository.sync();
      toast.success('Resync concluído — ${result['teams'] ?? '?'} teams');
    } catch (e) {
      toast.error('Falha ao ressincronizar: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    // Hidrata o controller uma única vez quando o fetch completa.
    configAsync.whenData((content) {
      if (!_hydrated) {
        _hydrated = true;
        _controller.text = content;
        _original = content;
        _validate(content);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
        title: Text('Configuração', style: AppTextStyles.heading1),
        actions: [
          IconButton(
            tooltip: 'Ressincronizar teams.json → DB',
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neonPurple,
                    ),
                  )
                : const Icon(Icons.sync, color: AppColors.neonPurple),
            onPressed: _syncing ? null : _syncOnly,
          ),
          IconButton(
            tooltip: 'Salvar teams.json',
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neonGreen,
                    ),
                  )
                : Icon(
                    Icons.save_outlined,
                    color: (_isValid && _isDirty && !_saving)
                        ? AppColors.neonGreen
                        : AppColors.textMuted,
                  ),
            onPressed: (_isValid && _isDirty && !_saving)
                ? _confirmAndSave
                : null,
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.neonBlue),
        ),
        error: (e, _) => EmptyState(
          message: 'Erro ao carregar teams.json\n$e',
          icon: Icons.error_outline,
          action: () => ref.invalidate(configProvider),
          actionLabel: 'Tentar novamente',
        ),
        data: (_) => RefreshIndicator(
          color: AppColors.neonBlue,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            _hydrated = false;
            ref.invalidate(configProvider);
            await ref.read(configProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isValid
                        ? AppColors.neonBlue.withOpacity(0.25)
                        : AppColors.neonRed.withOpacity(0.6),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 20,
                  keyboardType: TextInputType.multiline,
                  cursorColor: AppColors.neonBlue,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    color: AppColors.neonBlue,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '{\n  "version": "1.0",\n  "projects": []\n}',
                  ),
                  onChanged: _validate,
                ),
              ),
              if (_parseError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.neonRed, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _parseError!,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.neonRed,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                _isDirty
                    ? 'Alterações não salvas'
                    : 'Sincronizado com o servidor',
                style: AppTextStyles.label.copyWith(
                  color: _isDirty ? AppColors.neonYellow : AppColors.neonGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
