/// Resultado de um upload de imagem para o backend.
class UploadResult {
  const UploadResult({
    required this.id,
    required this.url,
    required this.filename,
    required this.size,
  });

  final String id;
  final String url;
  final String filename;
  final int size;

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
        id: json['id'] as String,
        url: json['url'] as String,
        filename: json['filename'] as String,
        size: json['size'] as int? ?? 0,
      );
}
