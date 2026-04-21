import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../../../core/network/api_client.dart';
import '../models/upload_result.dart';

/// Limite máximo por arquivo (após compressão) — alinhado ao allowance do backend.
const int kMaxFileBytes = 5 * 1024 * 1024; // 5 MB

/// Limite máximo de anexos por mensagem — alinhado com web.
const int kMaxAttachmentsPerMessage = 6;

/// MIME allowlist — alinhada ao backend (routes.ts).
const Set<String> kAllowedMimes = {
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
};

/// Serviço centralizado de upload de imagens.
/// Suporta 4 métodos de aquisição:
/// 1. Galeria — single (`pickFromGallery`)
/// 2. Galeria — multi (`pickMultiFromGallery`)
/// 3. Câmera (`pickFromCamera`)
/// 4. Clipboard / paste (`pickFromClipboard`, só desktop/web)
class ImageUploadService {
  ImageUploadService._();

  static final _imagePicker = ImagePicker();

  /// Faz upload de um único arquivo via `POST /upload/image`.
  /// Retorna [UploadResult] ou lança [DioException] em erro.
  static Future<UploadResult> uploadImage(
    XFile file, {
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    final dio = await ApiClient.getInstance();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      ),
    });

    final response = await dio.post(
      '/upload/image',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return UploadResult.fromJson(response.data as Map<String, dynamic>);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Upload falhou: HTTP ${response.statusCode}',
    );
  }

  /// Dispara uploads em paralelo, respeitando [cancelTokens] por índice.
  /// Retorna uma lista com o [Future<UploadResult>] de cada arquivo na mesma
  /// ordem — caller pode usar `await Future.wait(...)` ou aguardar individual.
  static List<Future<UploadResult>> uploadImages(
    List<XFile> files, {
    List<CancelToken>? cancelTokens,
    List<void Function(int sent, int total)>? onProgresses,
  }) {
    return List.generate(files.length, (i) {
      return uploadImage(
        files[i],
        cancelToken: cancelTokens?[i],
        onProgress: onProgresses?[i],
      );
    });
  }

  /// Seleciona uma única imagem da galeria.
  static Future<XFile?> pickFromGallery() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Galeria (single) erro: $e');
      return null;
    }
  }

  /// Seleciona múltiplas imagens da galeria (máx [limit], default 6).
  /// `image_picker ^1.1.0` expõe `pickMultiImage`.
  static Future<List<XFile>> pickMultiFromGallery({int limit = 6}) async {
    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        limit: limit,
      );
      // image_picker não corta no limit em todas as plataformas — fazemos defesa.
      return files.take(limit).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Galeria (multi) erro: $e');
      return const [];
    }
  }

  /// Captura uma foto com a câmera.
  /// No iOS o image_picker converte HEIC → JPEG automaticamente quando
  /// `imageQuality < 100`.
  static Future<XFile?> pickFromCamera() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Camera erro: $e');
      return null;
    }
  }

  /// Captura imagem da área de transferência (clipboard — desktop/web).
  static Future<XFile?> pickFromClipboard() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return XFile.fromData(
        imageBytes,
        mimeType: 'image/png',
        name: 'clipboard_$timestamp.png',
        length: imageBytes.length,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Clipboard erro: $e');
      return null;
    }
  }

  // ───────── Validação + Compressão ─────────

  /// Verifica se o MIME declarado do arquivo está na allowlist do backend.
  /// Se não tiver MIME explícito, infere pela extensão.
  static bool isAllowedMime(XFile file) {
    final mime = file.mimeType ?? _mimeFromExtension(file.path);
    return kAllowedMimes.contains(mime);
  }

  /// MIME inferido por extensão (fallback).
  static String? mimeOf(XFile file) {
    return file.mimeType ?? _mimeFromExtension(file.path);
  }

  static String? _mimeFromExtension(String path) {
    final ext = _extOf(path);
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Retorna a extensão (com `.`) em lowercase, ou '' se não houver.
  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    final slash = path.lastIndexOf(Platform.pathSeparator);
    if (dot < slash) return '';
    return path.substring(dot).toLowerCase();
  }

  /// Retorna o último segmento de um path (basename).
  static String _baseOf(String path) {
    final slash = path.lastIndexOf(Platform.pathSeparator);
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// Comprime o arquivo para caber em [maxBytes], escalonando qualidade.
  /// Se já estiver abaixo do limite, retorna o arquivo original sem tocar.
  /// Formatos suportados pelo `flutter_image_compress`: jpg, png, webp.
  /// GIFs passam adiante sem compressão (iria destruir animação).
  static Future<XFile> compressIfNeeded(
    XFile file, {
    int maxBytes = kMaxFileBytes,
  }) async {
    final bytes = await file.length();
    if (bytes <= maxBytes) return file;

    final mime = mimeOf(file);
    if (mime == 'image/gif') return file; // não comprime GIF

    // Escolhe formato output
    final format = mime == 'image/png'
        ? CompressFormat.png
        : mime == 'image/webp'
            ? CompressFormat.webp
            : CompressFormat.jpeg;

    // Tenta qualidade decrescente até caber.
    for (final quality in const [80, 65, 50, 35]) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: quality,
        format: format,
        keepExif: false,
      );
      if (compressed == null) break;
      if (compressed.length <= maxBytes) {
        // Persiste em arquivo temporário para virar XFile
        final tmpDir = Directory.systemTemp;
        final outPath =
            '${tmpDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${_baseOf(file.path)}';
        final out = File(outPath);
        await out.writeAsBytes(compressed);
        return XFile(outPath, name: file.name, mimeType: mime);
      }
    }
    // Não conseguiu caber — devolve original, validação fará rejeição.
    return file;
  }
}
