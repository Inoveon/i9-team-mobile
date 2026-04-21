import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Um anexo exibido na bolha do usuário. Pode ser:
/// - [localPath]: arquivo local (otimista — ainda aparecendo enquanto o eco
///   do backend não chega)
/// - [localBytes]: bytes em memória (Flutter Web — XFile.path é blob URL)
/// - [remoteUrl]: URL relativa retornada pelo backend (`/uploads/...`)
class BubbleAttachment {
  const BubbleAttachment({
    this.localPath,
    this.localBytes,
    this.remoteUrl,
    this.filename,
    this.failed = false,
  });

  final String? localPath;
  final Uint8List? localBytes;
  final String? remoteUrl;
  final String? filename;

  /// Marca visualmente o anexo como rejeitado pelo backend (HTTP 207).
  final bool failed;
}

/// Bolha de mensagem do usuário — alinhada à direita, fundo roxo/azul.
///
/// Onda 5: pode renderizar thumbs de anexos abaixo do texto.
class UserBubble extends StatelessWidget {
  const UserBubble({
    super.key,
    required this.text,
    this.attachments = const [],
    this.pending = false,
  });

  final String text;
  final List<BubbleAttachment> attachments;

  /// Se `true`, renderiza a bolha com opacidade reduzida + ícone de envio
  /// pendente no canto (estado otimista — ainda sem eco do backend).
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    final hasAttachments = attachments.isNotEmpty;

    return Opacity(
      opacity: pending ? 0.72 : 1.0,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 56, right: 12, top: 4, bottom: 4),
          padding: EdgeInsets.fromLTRB(
            14,
            hasText ? 10 : 8,
            14,
            hasAttachments ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), AppColors.neonBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.body.copyWith(color: Colors.white),
                    code: AppTextStyles.body.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.white70,
                      backgroundColor: Colors.black26,
                    ),
                  ),
                ),
              if (hasAttachments) ...[
                if (hasText) const SizedBox(height: 8),
                _AttachmentsGrid(attachments: attachments),
              ],
              if (pending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'enviando...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentsGrid extends StatelessWidget {
  const _AttachmentsGrid({required this.attachments});
  final List<BubbleAttachment> attachments;

  static const double _thumb = 96;
  static const double _spacing = 6;

  @override
  Widget build(BuildContext context) {
    // Max 3 colunas — fica bom em celular comum
    final cols = attachments.length == 1 ? 1 : (attachments.length == 2 ? 2 : 3);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _thumb * cols + _spacing * (cols - 1),
      ),
      child: Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        alignment: WrapAlignment.end,
        children: [
          for (final a in attachments)
            _Thumb(attachment: a, size: _thumb),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.attachment, required this.size});
  final BubbleAttachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(
            color: attachment.failed
                ? AppColors.neonRed.withOpacity(0.7)
                : Colors.white24,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ImageWidget(attachment: attachment),
            if (attachment.failed)
              Container(
                color: AppColors.neonRed.withOpacity(0.25),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageWidget extends StatelessWidget {
  const _ImageWidget({required this.attachment});
  final BubbleAttachment attachment;

  @override
  Widget build(BuildContext context) {
    // Ordem de precedência: bytes > local file > remote URL
    if (attachment.localBytes != null) {
      return Image.memory(attachment.localBytes!, fit: BoxFit.cover);
    }
    if (!kIsWeb && attachment.localPath != null && attachment.localPath!.isNotEmpty) {
      return Image.file(
        File(attachment.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _remoteFallback(),
      );
    }
    return _remoteFallback();
  }

  Widget _remoteFallback() {
    if (attachment.remoteUrl == null || attachment.remoteUrl!.isEmpty) {
      return const ColoredBox(
        color: Colors.black26,
        child: Icon(Icons.broken_image, color: Colors.white70, size: 28),
      );
    }
    return Image.network(
      attachment.remoteUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Colors.black26,
        child: Icon(Icons.image_not_supported, color: Colors.white70, size: 28),
      ),
    );
  }
}
