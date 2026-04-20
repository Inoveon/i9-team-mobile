import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../models/note.dart';
import '../notes_provider.dart';

/// Tela 3: editor da nota. Faz POST quando [isNew] ou PUT caso contrário.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.teamId,
    required this.noteName,
    required this.initialContent,
    this.initialEtag,
    this.isNew = false,
  });

  final String teamId;
  final String noteName;
  final String initialContent;
  final String? initialEtag;
  final bool isNew;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _controller;
  late String _originalContent;
  String? _etag;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _originalContent = widget.initialContent;
    _etag = widget.initialEtag;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDirty => _controller.text != _originalContent;

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonYellow.withOpacity(0.4)),
        ),
        title: Text('Descartar mudanças?', style: AppTextStyles.heading2),
        content: Text(
          'Você tem edições não salvas. Sair perde as alterações.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Continuar editando',
              style: AppTextStyles.body.copyWith(color: AppColors.neonBlue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Descartar',
              style: AppTextStyles.body.copyWith(
                color: AppColors.neonRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final repo = ref.read(notesRepositoryProvider(widget.teamId));
    final content = _controller.text;

    try {
      Note saved;
      if (widget.isNew) {
        saved = await repo.create(widget.noteName, content);
      } else {
        saved = await repo.save(
          widget.noteName,
          content,
          expectedEtag: _etag,
        );
      }
      if (!mounted) return;
      setState(() {
        _etag = saved.etag;
        _originalContent = content;
      });
      ref.read(toastProvider.notifier).success('Nota salva');
      ref.invalidate(notesListProvider(widget.teamId));
      ref.invalidate(
        noteProvider(NoteKey(widget.teamId, widget.noteName)),
      );
    } on NoteConflict catch (conflict) {
      if (!mounted) return;
      // Libera o lock antes de abrir o toast com actions (force-save recursivo).
      setState(() => _saving = false);
      _handleConflict(conflict);
      return;
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final toast = ref.read(toastProvider.notifier);
      if (status == 400) {
        toast.error('Nome inválido (400).');
      } else if (status == 409) {
        toast.error('Conflito não resolvido.');
      } else if (status == 404) {
        toast.error('Nota não encontrada (404).');
      } else {
        _toastRetry('Falha ao salvar: ${e.message ?? e}');
      }
    } catch (e) {
      if (!mounted) return;
      _toastRetry('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Conflito 409 agora é toast warning com actions [Recarregar, Forçar salvar].
  /// TTL longo (12s default por ter actions) dá tempo de decisão sem modal.
  void _handleConflict(NoteConflict conflict) {
    final toast = ref.read(toastProvider.notifier);
    toast.warning(
      'A nota foi modificada no servidor enquanto você editava.',
      title: 'Conflito de edição',
      actions: [
        ToastAction(
          label: 'Recarregar',
          onTap: () {
            if (!mounted) return;
            setState(() {
              _controller.text = conflict.currentContent;
              _originalContent = conflict.currentContent;
              _etag = conflict.currentEtag;
            });
            ref
                .read(toastProvider.notifier)
                .info('Conteúdo do servidor carregado.');
          },
        ),
        ToastAction(
          label: 'Forçar salvar',
          primary: true,
          onTap: () {
            if (!mounted) return;
            setState(() => _etag = null);
            _save();
          },
        ),
      ],
    );
  }

  void _toastRetry(String msg) {
    ref.read(toastProvider.notifier).error(
      msg,
      actions: [
        ToastAction(
          label: 'Tentar novamente',
          primary: true,
          onTap: _save,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          iconTheme: const IconThemeData(color: AppColors.neonBlue),
          title: Text(
            widget.noteName,
            style: AppTextStyles.heading2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonBlue,
                        ),
                      )
                    : const Icon(Icons.save_outlined,
                        color: AppColors.neonGreen, size: 20),
                label: Text(
                  _saving ? 'Salvando…' : 'Salvar',
                  style: AppTextStyles.body.copyWith(
                    color: _saving
                        ? AppColors.textMuted
                        : AppColors.neonGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.neonBlue.withOpacity(0.2),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              autofocus: widget.isNew,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: AppColors.neonBlue,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: AppColors.text,
                height: 1.4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '# Título\n\nConteúdo em markdown…',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }
}
