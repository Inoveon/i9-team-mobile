import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../models/upload_result.dart';

/// Serviço centralizado de upload de imagens.
/// Suporta 3 métodos de aquisição:
/// 1. Clipboard (paste)
/// 2. Galeria (image_picker)
/// 3. Arquivo qualquer (image_picker)
class ImageUploadService {
  ImageUploadService._();

  static final _imagePicker = ImagePicker();

  /// Faz upload de um arquivo de imagem para o backend.
  /// POST multipart para /upload/image
  /// Retorna UploadResult com { id, url, filename, size } ou null em erro.
  static Future<UploadResult?> uploadImage(XFile file) async {
    try {
      final dio = await ApiClient.getInstance();
      final baseUrl = await AppConfig.getBackendUrl();

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });

      final response = await dio.post(
        '$baseUrl/upload/image',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return UploadResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  /// Seleciona imagem da galeria do dispositivo.
  static Future<XFile?> pickFromGallery() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      print('Galeria error: $e');
      return null;
    }
  }

  /// Captura imagem da área de transferência (clipboard).
  /// Retorna XFile criado a partir do PNG em memória.
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
      print('Clipboard error: $e');
      return null;
    }
  }
}
