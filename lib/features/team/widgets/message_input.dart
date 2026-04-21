import 'dart:io' show File, Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../../upload/models/pending_attachment.dart';
import '../../upload/providers/pending_attachments_provider.dart';
import '../../upload/services/image_upload_service.dart';

/// Callback legado (Onda 4) — mantido para não quebrar TeamScreen. Será
/// descontinuado na Parte 2 quando o payload aceitar `attachmentIds`.
typedef OnUploadSuccess = Future<void> Function(dynamic _);

class MessageInput extends ConsumerStatefulWidget {
  const MessageInput({
    super.key,
    required this.teamId,
    required this.onSend,
    this.onImageUpload,
    this.sessionName,
  });

  /// TeamId para isolar a lista de anexos pendentes.
  final String teamId;

  /// Callback chamado ao enviar a mensagem. Texto puro por enquanto — a
  /// Parte 2 passará também os IDs dos anexos remotos concluídos.
  final void Function(String message) onSend;

  /// Legado — preservado até Parte 2 remover o callback.
  final OnUploadSuccess? onImageUpload;

  final String? sessionName;

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  static const double _buttonSize = 44;
  static const double _thumbSize = 48;
  static const double _previewBarHeight = 72;

  /// Mostra opção de Clipboard apenas em ambientes onde `pasteboard` tem suporte
  /// consistente a imagem (desktop e web). Em Android/iOS, `pasteboard.image`
  /// pode retornar null mesmo com conteúdo válido.
  bool get _showClipboardOption {
    if (kIsWeb) return true;
    try {
      return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final msg = _controller.text.trim();
    final hasPending =
        ref.read(pendingAttachmentsProvider(widget.teamId)).isNotEmpty;
    if (msg.isEmpty && !hasPending) return;

    widget.onSend(msg);
    _controller.clear();
    // Parte 2 limpará os anexos ao confirmar envio completo;
    // por ora, mantemos a lista até backend confirmar o contrato.
  }

  // ────────────────────── Pickers ──────────────────────

  Future<void> _handleCameraPick() async {
    final file = await ImageUploadService.pickFromCamera();
    if (file == null) return;
    await _addFiles([file]);
  }

  Future<void> _handleGalleryPick() async {
    final files = await ImageUploadService.pickMultiFromGallery(
      limit: kMaxAttachmentsPerMessage,
    );
    if (files.isEmpty) return;
    await _addFiles(files);
  }

  Future<void> _handleClipboardPick() async {
    final file = await ImageUploadService.pickFromClipboard();
    if (file == null) {
      ref
          .read(toastProvider.notifier)
          .info('Nenhuma imagem na área de transferência');
      return;
    }
    await _addFiles([file]);
  }

  Future<void> _addFiles(List<XFile> files) async {
    SemanticsService.announce(
      'Anexando ${files.length} ${files.length == 1 ? 'imagem' : 'imagens'}...',
      TextDirection.ltr,
    );
    final report = await ref
        .read(pendingAttachmentsProvider(widget.teamId).notifier)
        .addFiles(files);

    final toast = ref.read(toastProvider.notifier);
    if (report.rejectedByLimit > 0) {
      toast.warning(
        'Máximo $kMaxAttachmentsPerMessage imagens por mensagem — '
        '${report.rejectedByLimit} descartada(s).',
      );
    }
    if (report.rejectedByMime.isNotEmpty) {
      toast.error(
        'Tipo não suportado: ${report.rejectedByMime.take(3).join(", ")}',
      );
    }
    if (report.rejectedBySize.isNotEmpty) {
      toast.error(
        'Imagem muito grande (>5MB após compressão): '
        '${report.rejectedBySize.take(3).join(", ")}',
      );
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PickerSheet(
        showClipboard: _showClipboardOption,
        onCamera: () {
          Navigator.of(ctx).pop();
          _handleCameraPick();
        },
        onGallery: () {
          Navigator.of(ctx).pop();
          _handleGalleryPick();
        },
        onClipboard: () {
          Navigator.of(ctx).pop();
          _handleClipboardPick();
        },
      ),
    );
  }

  // ────────────────────── Build ──────────────────────

  @override
  Widget build(BuildContext context) {
    // Observa transições de estado para anúncios acessíveis + toasts.
    ref.listen<List<PendingAttachment>>(
      pendingAttachmentsProvider(widget.teamId),
      (prev, next) {
        if (prev == null) return;
        // detecta itens que acabaram de concluir upload
        for (final n in next) {
          final p = prev.firstWhere(
            (e) => e.clientId == n.clientId,
            orElse: () => n,
          );
          if (!p.done && n.done) {
            SemanticsService.announce(
              'Imagem ${n.local.name} anexada',
              TextDirection.ltr,
            );
          } else if (p.error == null && n.error != null) {
            SemanticsService.announce(
              'Falha ao anexar ${n.local.name}: ${n.error}',
              TextDirection.ltr,
            );
            ref.read(toastProvider.notifier).error(
                  'Falha no anexo "${n.local.name}": ${n.error}',
                );
          }
        }
      },
    );

    final attachments = ref.watch(pendingAttachmentsProvider(widget.teamId));
    final canSend = _hasText ||
        attachments.any((a) => a.done); // permite enviar só com anexo

    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachments.isNotEmpty)
            _PreviewBar(
              attachments: attachments,
              onRemove: (id) => ref
                  .read(pendingAttachmentsProvider(widget.teamId).notifier)
                  .remove(id),
              onRetry: (id) => ref
                  .read(pendingAttachmentsProvider(widget.teamId).notifier)
                  .retry(id),
              height: _previewBarHeight,
              thumbSize: _thumbSize,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 📎 Botão anexar
                Semantics(
                  button: true,
                  label: 'Anexar imagem',
                  child: _IconButton(
                    onTap: _showPickerSheet,
                    icon: Icons.attach_file_rounded,
                    color: AppColors.neonBlue,
                    size: _buttonSize,
                    tooltip: 'Anexar imagem',
                  ),
                ),
                const SizedBox(width: 6),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
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
                        borderSide: const BorderSide(
                            color: AppColors.neonBlue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ▶ Enviar
                AnimatedOpacity(
                  opacity: canSend ? 1 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  child: Semantics(
                    button: true,
                    label: 'Enviar mensagem',
                    enabled: canSend,
                    child: GestureDetector(
                      onTap: canSend ? _send : null,
                      child: Container(
                        width: _buttonSize,
                        height: _buttonSize,
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.neonBlue.withOpacity(0.5)),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: AppColors.neonBlue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Widgets auxiliares
// ────────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.size,
    this.tooltip,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.attachments,
    required this.onRemove,
    required this.onRetry,
    required this.height,
    required this.thumbSize,
  });

  final List<PendingAttachment> attachments;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onRetry;
  final double height;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
          top: BorderSide(color: AppColors.neonBlue.withOpacity(0.12)),
          bottom: BorderSide(color: AppColors.neonBlue.withOpacity(0.12)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = attachments[i];
          return _Thumb(
            attachment: a,
            size: thumbSize,
            onRemove: () => onRemove(a.clientId),
            onRetry: () => onRetry(a.clientId),
            index: i + 1,
            total: attachments.length,
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.attachment,
    required this.size,
    required this.onRemove,
    required this.onRetry,
    required this.index,
    required this.total,
  });

  final PendingAttachment attachment;
  final double size;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    Color border;
    if (a.hasError) {
      border = AppColors.neonRed.withOpacity(0.6);
    } else if (a.done) {
      border = AppColors.neonGreen.withOpacity(0.6);
    } else {
      border = AppColors.neonBlue.withOpacity(0.4);
    }

    return Semantics(
      label: a.hasError
          ? 'Anexo $index de $total: ${a.local.name}. Erro: ${a.error}. Toque para tentar novamente.'
          : 'Anexo $index de $total: ${a.local.name}${a.done ? ", enviado" : ", enviando"}.',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Thumb base
            GestureDetector(
              onTap: a.hasError ? onRetry : null,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 1.5),
                  color: AppColors.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _ThumbImage(attachment: a),
                ),
              ),
            ),
            // Loading overlay
            if (a.uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.bg.withOpacity(0.5),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: (a.progress != null && a.progress! > 0)
                            ? a.progress
                            : null,
                        strokeWidth: 2,
                        color: AppColors.neonBlue,
                        backgroundColor:
                            AppColors.neonBlue.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
              ),
            // Check verde — sucesso
            if (a.done)
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.neonGreen,
                    size: 14,
                  ),
                ),
              ),
            // Ícone de erro
            if (a.hasError)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.neonRed.withOpacity(0.15),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: AppColors.neonRed,
                      size: 18,
                    ),
                  ),
                ),
              ),
            // Botão X remover
            Positioned(
              top: -6,
              right: -6,
              child: Semantics(
                button: true,
                label: 'Remover ${a.local.name}',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.neonRed.withOpacity(0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: AppColors.neonRed,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  const _ThumbImage({required this.attachment});
  final PendingAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // XFile.path em web é um blob URL — tem que usar readAsBytes
      return FutureBuilder(
        future: attachment.local.readAsBytes(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const ColoredBox(color: AppColors.surface);
          }
          return Image.memory(snap.data!, fit: BoxFit.cover);
        },
      );
    }
    return Image.file(
      File(attachment.local.path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: AppColors.surface,
        child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 18),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Bottom sheet — escolha da fonte
// ────────────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.showClipboard,
    required this.onCamera,
    required this.onGallery,
    required this.onClipboard,
  });

  final bool showClipboard;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClipboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg.withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
                left: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
                right: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.1),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'ANEXAR IMAGEM',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.neonBlue,
                          letterSpacing: 0.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'até $kMaxAttachmentsPerMessage imagens · máx 5MB',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _PickerOption(
                  icon: Icons.photo_camera_outlined,
                  label: 'Câmera',
                  sub: 'Tirar uma foto agora',
                  onTap: onCamera,
                ),
                _PickerOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeria',
                  sub: 'Escolher até $kMaxAttachmentsPerMessage imagens',
                  onTap: onGallery,
                ),
                if (showClipboard)
                  _PickerOption(
                    icon: Icons.content_paste_rounded,
                    label: 'Área de transferência',
                    sub: 'Colar imagem copiada',
                    onTap: onClipboard,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerOption extends StatefulWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  State<_PickerOption> createState() => _PickerOptionState();
}

class _PickerOptionState extends State<_PickerOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _pressed
              ? AppColors.neonBlue.withOpacity(0.18)
              : AppColors.neonBlue.withOpacity(0.06),
          border: Border.all(
            color: _pressed
                ? AppColors.neonBlue.withOpacity(0.55)
                : AppColors.neonBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: AppColors.neonBlue, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.sub,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}
