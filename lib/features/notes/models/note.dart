/// Resumo de nota para a listagem.
class NoteSummary {
  const NoteSummary({
    required this.name,
    required this.size,
    required this.updatedAt,
  });

  final String name;
  final int size;
  final DateTime updatedAt;

  factory NoteSummary.fromJson(Map<String, dynamic> json) {
    return NoteSummary(
      name: json['name'] as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

/// Nota completa com conteúdo e etag para controle de concorrência.
class Note {
  const Note({
    required this.name,
    required this.content,
    required this.size,
    required this.updatedAt,
    required this.etag,
  });

  final String name;
  final String content;
  final int size;
  final DateTime updatedAt;
  final String etag;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      name: json['name'] as String,
      content: (json['content'] as String?) ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(json['updatedAt']),
      etag: (json['etag'] as String?) ?? '',
    );
  }

  Note copyWith({
    String? name,
    String? content,
    int? size,
    DateTime? updatedAt,
    String? etag,
  }) {
    return Note(
      name: name ?? this.name,
      content: content ?? this.content,
      size: size ?? this.size,
      updatedAt: updatedAt ?? this.updatedAt,
      etag: etag ?? this.etag,
    );
  }
}

/// Conflito retornado pelo PUT quando o etag do cliente está desatualizado.
class NoteConflict implements Exception {
  const NoteConflict({
    required this.currentEtag,
    required this.currentContent,
  });

  final String currentEtag;
  final String currentContent;

  @override
  String toString() =>
      'NoteConflict(currentEtag: $currentEtag, size: ${currentContent.length})';
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String) {
    return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
  }
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
  }
  return DateTime.now();
}
