import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'upload_result.dart';

/// Anexo em preparação no `MessageInput` — pode estar em upload, com erro,
/// ou já concluído (com [remote] preenchido).
///
/// Imutável — para mutação, use `copyWith`.
class PendingAttachment {
  /// ID interno do cliente (pode casar com `remote?.id` após sucesso, mas
  /// mantemos um próprio para permitir remover itens que ainda não subiram).
  final String clientId;

  /// Arquivo local capturado (galeria/câmera/clipboard).
  final XFile local;

  /// Resultado do upload ao backend — `null` enquanto não concluiu.
  final UploadResult? remote;

  /// Flag: upload em andamento.
  final bool uploading;

  /// Progresso 0.0..1.0 (null se ainda não iniciou ou concluído).
  final double? progress;

  /// Mensagem de erro amigável (null se OK).
  final String? error;

  /// Token para cancelar o upload em curso.
  final CancelToken cancel;

  const PendingAttachment({
    required this.clientId,
    required this.local,
    this.remote,
    this.uploading = false,
    this.progress,
    this.error,
    required this.cancel,
  });

  bool get done => remote != null;
  bool get hasError => error != null;

  PendingAttachment copyWith({
    UploadResult? remote,
    bool? uploading,
    double? progress,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) =>
      PendingAttachment(
        clientId: clientId,
        local: local,
        remote: remote ?? this.remote,
        uploading: uploading ?? this.uploading,
        progress: clearProgress ? null : (progress ?? this.progress),
        error: clearError ? null : (error ?? this.error),
        cancel: cancel,
      );
}
