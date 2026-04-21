import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pending_attachment.dart';
import '../services/image_upload_service.dart';

/// Resultado de uma tentativa de adicionar anexo — usado pela UI para decidir
/// qual toast exibir.
class AddAttachmentReport {
  final int added;
  final int rejectedByLimit;
  final List<String> rejectedByMime;
  final List<String> rejectedBySize;

  const AddAttachmentReport({
    this.added = 0,
    this.rejectedByLimit = 0,
    this.rejectedByMime = const [],
    this.rejectedBySize = const [],
  });

  bool get hasRejects =>
      rejectedByLimit > 0 ||
      rejectedByMime.isNotEmpty ||
      rejectedBySize.isNotEmpty;
}

/// Gerencia a lista de anexos pendentes para um `teamId` específico.
///
/// Responsabilidades:
/// 1. Validar MIME/size/count localmente antes de subir.
/// 2. Comprimir (flutter_image_compress) arquivos >5MB.
/// 3. Orquestrar uploads paralelos com `CancelToken` + progresso.
/// 4. Limpar todos ao enviar a mensagem (`clear()`).
class PendingAttachmentsNotifier
    extends StateNotifier<List<PendingAttachment>> {
  PendingAttachmentsNotifier() : super(const []);

  int _counter = 0;
  String _nextId() => 'att_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Adiciona múltiplos arquivos: valida, comprime se preciso, dispara upload.
  /// Retorna report com estatísticas para a UI.
  Future<AddAttachmentReport> addFiles(List<XFile> files) async {
    if (files.isEmpty) return const AddAttachmentReport();

    var added = 0;
    var rejectedByLimit = 0;
    final rejectedByMime = <String>[];
    final rejectedBySize = <String>[];

    for (final raw in files) {
      // (1) limite global de anexos por mensagem
      if (state.length >= kMaxAttachmentsPerMessage) {
        rejectedByLimit++;
        continue;
      }

      // (2) MIME allowlist
      if (!ImageUploadService.isAllowedMime(raw)) {
        rejectedByMime.add(raw.name);
        continue;
      }

      // (3) Compressão se necessário (PNG/JPEG/WEBP)
      XFile file = raw;
      try {
        file = await ImageUploadService.compressIfNeeded(raw);
      } catch (_) {
        // compressão falhou — prossegue com original; validação de size abaixo decide.
      }

      // (4) size guard (pós-compressão)
      final bytes = await file.length();
      if (bytes > kMaxFileBytes) {
        rejectedBySize.add(file.name);
        continue;
      }

      final pending = PendingAttachment(
        clientId: _nextId(),
        local: file,
        uploading: true,
        progress: 0,
        cancel: CancelToken(),
      );
      state = [...state, pending];
      added++;

      _startUpload(pending.clientId);
    }

    return AddAttachmentReport(
      added: added,
      rejectedByLimit: rejectedByLimit,
      rejectedByMime: rejectedByMime,
      rejectedBySize: rejectedBySize,
    );
  }

  /// Dispara upload do arquivo identificado por [clientId] — fire & forget.
  /// A listagem [state] é atualizada em progress/erro/sucesso.
  void _startUpload(String clientId) async {
    final index = state.indexWhere((a) => a.clientId == clientId);
    if (index < 0) return;
    final att = state[index];

    try {
      final result = await ImageUploadService.uploadImage(
        att.local,
        cancelToken: att.cancel,
        onProgress: (sent, total) {
          if (total <= 0) return;
          _patch(clientId, (a) => a.copyWith(progress: sent / total));
        },
      );
      _patch(
        clientId,
        (a) => a.copyWith(
          remote: result,
          uploading: false,
          clearError: true,
          progress: 1.0,
        ),
      );
    } on DioException catch (e) {
      // Cancelamento silencioso — o item já foi removido em `remove`.
      if (CancelToken.isCancel(e)) return;
      _patch(
        clientId,
        (a) => a.copyWith(
          uploading: false,
          error: _friendlyError(e),
          clearProgress: true,
        ),
      );
    } catch (e) {
      _patch(
        clientId,
        (a) => a.copyWith(
          uploading: false,
          error: 'Falha inesperada: $e',
          clearProgress: true,
        ),
      );
    }
  }

  /// Remove anexo — cancela upload em curso se ainda estiver subindo.
  void remove(String clientId) {
    final att = state.firstWhere(
      (a) => a.clientId == clientId,
      orElse: () => _missing,
    );
    if (identical(att, _missing)) return;
    if (att.uploading && !att.cancel.isCancelled) {
      att.cancel.cancel('Removido pelo usuário');
    }
    state = state.where((a) => a.clientId != clientId).toList();
  }

  /// Reagenda upload de um item em erro.
  void retry(String clientId) {
    final att = state.firstWhere(
      (a) => a.clientId == clientId,
      orElse: () => _missing,
    );
    if (identical(att, _missing)) return;
    if (att.uploading) return;
    _patch(
      clientId,
      (a) => a.copyWith(
        uploading: true,
        clearError: true,
        progress: 0,
      ),
    );
    _startUpload(clientId);
  }

  /// Limpa a lista (chamado ao enviar mensagem com sucesso).
  /// Cancela uploads em curso, por segurança.
  void clear() {
    for (final a in state) {
      if (a.uploading && !a.cancel.isCancelled) {
        a.cancel.cancel('Chat fechado');
      }
    }
    state = const [];
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  // ─── helpers ──────────────────────────────────────

  void _patch(
    String clientId,
    PendingAttachment Function(PendingAttachment) mutate,
  ) {
    state = [
      for (final a in state)
        if (a.clientId == clientId) mutate(a) else a,
    ];
  }

  static final PendingAttachment _missing = PendingAttachment(
    clientId: '__missing__',
    local: XFile(''),
    cancel: CancelToken(),
  );

  static String _friendlyError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 413) return 'Imagem muito grande (máx. 10MB)';
    if (code == 415) return 'Tipo de imagem não suportado';
    if (code == 401) return 'Sessão expirada — refaça o login';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Tempo esgotado — verifique sua conexão';
    }
    if (e.error is SocketException) return 'Sem conexão com o servidor';
    return 'Falha ao enviar (${code ?? e.type.name})';
  }
}

/// Provider parametrizado por `teamId` — isola as listas de diferentes teams.
final pendingAttachmentsProvider = StateNotifierProvider.family<
    PendingAttachmentsNotifier, List<PendingAttachment>, String>(
  (ref, teamId) => PendingAttachmentsNotifier(),
);
