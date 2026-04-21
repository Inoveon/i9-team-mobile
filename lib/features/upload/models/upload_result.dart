/// Resultado de um upload de imagem via `POST /upload/image`.
///
/// Backend retorna:
/// ```
/// { id, url, filename, size, mimetype, createdAt }
/// ```
class UploadResult {
  const UploadResult({
    required this.id,
    required this.url,
    required this.filename,
    required this.size,
    this.mimetype,
    this.createdAt,
  });

  final String id;
  final String url;
  final String filename;
  final int size;
  final String? mimetype;
  final String? createdAt;

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
        id: json['id'] as String,
        url: json['url'] as String,
        filename: json['filename'] as String,
        size: (json['size'] as int?) ?? 0,
        mimetype: json['mimetype'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'filename': filename,
        'size': size,
        if (mimetype != null) 'mimetype': mimetype,
        if (createdAt != null) 'createdAt': createdAt,
      };
}
