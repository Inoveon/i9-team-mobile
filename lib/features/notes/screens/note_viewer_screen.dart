import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../notes_provider.dart';
import 'note_editor_screen.dart';

/// Tela 2: visualiza uma nota renderizada como markdown.
class NoteViewerScreen extends ConsumerWidget {
  const NoteViewerScreen({
    super.key,
    required this.teamId,
    required this.noteName,
  });

  final String teamId;
  final String noteName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = NoteKey(teamId, noteName);
    final noteAsync = ref.watch(noteProvider(key));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
        title: Text(
          noteName,
          style: AppTextStyles.heading2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          noteAsync.maybeWhen(
            data: (note) => IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.neonBlue),
              tooltip: 'Editar',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(
                      teamId: teamId,
                      noteName: noteName,
                      initialContent: note.content,
                      initialEtag: note.etag,
                    ),
                  ),
                );
                // Invalida e refaz fetch ao voltar do editor.
                ref.invalidate(noteProvider(key));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.neonBlue),
        ),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(noteProvider(key)),
        ),
        data: (note) {
          if (note.content.isEmpty) {
            return const EmptyState(
              message: 'Nota vazia. Toque em Editar para começar.',
              icon: Icons.description_outlined,
            );
          }
          return Markdown(
            data: note.content,
            padding: const EdgeInsets.all(16),
            selectable: true,
            styleSheet: _markdownStyle(),
          );
        },
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    final body = AppTextStyles.body.copyWith(height: 1.5);
    return MarkdownStyleSheet(
      p: body,
      h1: AppTextStyles.heading1,
      h2: AppTextStyles.heading2,
      h3: AppTextStyles.heading2.copyWith(fontSize: 16),
      h4: AppTextStyles.heading2.copyWith(fontSize: 15),
      code: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        color: AppColors.neonGreen,
        backgroundColor: AppColors.surface,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: body.copyWith(
        color: AppColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.neonBlue, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      listBullet: body.copyWith(color: AppColors.neonBlue),
      a: body.copyWith(
        color: AppColors.neonBlue,
        decoration: TextDecoration.underline,
      ),
      tableHead: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      tableBody: AppTextStyles.body,
      tableBorder: TableBorder.all(
        color: AppColors.neonBlue.withOpacity(0.2),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.neonBlue.withOpacity(0.3)),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final is404 = message.contains('404');
    return EmptyState(
      message: is404
          ? 'Nota não encontrada.'
          : 'Erro ao carregar nota\n$message',
      icon: is404 ? Icons.search_off : Icons.error_outline,
      action: onRetry,
      actionLabel: 'Tentar novamente',
    );
  }
}
