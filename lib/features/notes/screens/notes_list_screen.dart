import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../models/note.dart';
import '../notes_provider.dart';
import '../widgets/new_note_dialog.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';
import 'note_viewer_screen.dart';

/// Tela 1: listagem de notas do team com busca e criação.
///
/// Pode ser usada:
/// - Standalone (rota `/team/:id/notes`): com `Scaffold` + `AppBar` + `FAB`
/// - Embedded (dentro de uma Tab na TeamScreen): sem Scaffold — só o corpo,
///   FAB segue mas padding top se ajusta. Passe `embedded: true`.
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({
    super.key,
    required this.teamId,
    this.embedded = false,
    this.initialNoteName,
  });

  final String teamId;
  final bool embedded;

  /// Se presente, abre o viewer dessa nota automaticamente ao montar
  /// (deep-link `?note=` vindo da URL).
  final String? initialNoteName;

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _autoOpenTried = false;

  @override
  void initState() {
    super.initState();
    // Auto-abre a nota do deep-link na primeira frame. Fazer aqui (vs build)
    // garante que só roda uma vez por instância.
    if (widget.initialNoteName != null &&
        widget.initialNoteName!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoOpenTried) return;
        _autoOpenTried = true;
        _openNote(widget.initialNoteName!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNote(String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteViewerScreen(
          teamId: widget.teamId,
          noteName: name,
        ),
      ),
    );
    // Volta da visualização → refresh da lista (mtime pode ter mudado).
    ref.invalidate(notesListProvider(widget.teamId));
  }

  Future<void> _createNote() async {
    final name = await NewNoteDialog.show(context);
    if (name == null || !mounted) return;
    // Vai direto pro editor com conteúdo vazio; persistência é no Save.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          teamId: widget.teamId,
          noteName: name,
          initialContent: '# ${name.replaceAll('.md', '')}\n\n',
          isNew: true,
        ),
      ),
    );
    ref.invalidate(notesListProvider(widget.teamId));
  }

  Future<void> _confirmDelete(NoteSummary note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neonRed.withOpacity(0.4)),
        ),
        title: Text('Excluir nota', style: AppTextStyles.heading2),
        content: Text(
          'Excluir "${note.name}"? Essa ação não pode ser desfeita.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Excluir',
              style: AppTextStyles.body.copyWith(
                color: AppColors.neonRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final toast = ref.read(toastProvider.notifier);
    try {
      final repo = ref.read(notesRepositoryProvider(widget.teamId));
      await repo.delete(note.name);
      toast.success('Nota "${note.name}" excluída');
      ref.invalidate(notesListProvider(widget.teamId));
    } catch (e) {
      toast.error('Falha ao excluir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider(widget.teamId));

    final body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: AppTextStyles.body,
              cursorColor: AppColors.neonBlue,
              decoration: InputDecoration(
                hintText: 'Buscar nota…',
                hintStyle: AppTextStyles.bodyMuted,
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.neonBlue, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.neonBlue.withOpacity(0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neonBlue),
                ),
              ),
            ),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.neonBlue,
                ),
              ),
              error: (e, _) => EmptyState(
                message: 'Erro ao carregar notas\n$e',
                icon: Icons.error_outline,
                action: () => ref.invalidate(notesListProvider(widget.teamId)),
                actionLabel: 'Tentar novamente',
              ),
              data: (notes) {
                final filtered = _query.isEmpty
                    ? notes
                    : notes
                        .where((n) => n.name.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: _query.isEmpty
                        ? 'Nenhuma nota ainda.\nCrie a primeira no botão +.'
                        : 'Nenhuma nota com "$_query".',
                    icon: _query.isEmpty
                        ? Icons.note_outlined
                        : Icons.search_off,
                  );
                }
                return RefreshIndicator(
                  color: AppColors.neonBlue,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref.invalidate(notesListProvider(widget.teamId));
                    await ref.read(notesListProvider(widget.teamId).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final n = filtered[i];
                      // Cascata de entrada — delay 30ms por item (máx 6 ~= 180ms)
                      final delay = (i < 6 ? i : 6) * 30;
                      return NoteCard(
                        note: n,
                        onTap: () => _openNote(n.name),
                        onDelete: () => _confirmDelete(n),
                      )
                          .animate()
                          .fadeIn(
                            duration: 200.ms,
                            delay: Duration(milliseconds: delay),
                          )
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            duration: 200.ms,
                            delay: Duration(milliseconds: delay),
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                );
              },
            ),
          ),
        ],
    );

    final fab = FloatingActionButton(
      backgroundColor: AppColors.neonPurple,
      onPressed: _createNote,
      heroTag: 'notes_fab_${widget.teamId}',
      child: const Icon(Icons.add, color: Colors.white),
    );

    if (widget.embedded) {
      // Dentro de Tab — sem Scaffold, sem AppBar. FAB posicionado dentro do body.
      return Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(bottom: 16, right: 16, child: fab),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
        title: Text('Notas', style: AppTextStyles.heading1),
      ),
      body: body,
      floatingActionButton: fab,
    );
  }
}
