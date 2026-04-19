/// Modelo que representa um evento do stream message_stream do WebSocket.
///
/// O backend emite:
/// { "type": "message_stream", "session": "...", "events": [ {...}, ... ] }
///
/// Cada item do array "events" é deserializado como [MessageEvent].
class MessageEvent {
  final MessageEventType type;
  final String? text;
  final String? toolName;
  final String? toolArgs;
  final String? toolId;
  final String? toolContent;
  final String? menuTitle;
  final List<String> menuOptions;

  const MessageEvent({
    required this.type,
    this.text,
    this.toolName,
    this.toolArgs,
    this.toolId,
    this.toolContent,
    this.menuTitle,
    this.menuOptions = const [],
  });

  factory MessageEvent.fromJson(Map<String, dynamic> json) {
    final raw = (json['type'] as String?) ?? '';
    final type = _parseType(raw);

    return MessageEvent(
      type: type,
      text: json['text'] as String?,
      toolName: json['name'] as String?,
      toolArgs: json['args'] as String?,
      toolId: json['id'] as String?,
      toolContent: json['content'] as String?,
      menuTitle: json['title'] as String?,
      menuOptions: _parseOptions(json['options']),
    );
  }

  static MessageEventType _parseType(String raw) {
    switch (raw) {
      case 'user_input':
        return MessageEventType.userInput;
      case 'claude_text':
        return MessageEventType.claudeText;
      case 'tool_call':
        return MessageEventType.toolCall;
      case 'tool_result':
        return MessageEventType.toolResult;
      case 'thinking':
        return MessageEventType.thinking;
      case 'system':
        return MessageEventType.system;
      case 'interactive_menu':
        return MessageEventType.interactiveMenu;
      default:
        return MessageEventType.system;
    }
  }

  static List<String> _parseOptions(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map) return (e['label'] as String?) ?? e.toString();
        return e.toString();
      }).toList();
    }
    return [];
  }

  @override
  String toString() => 'MessageEvent(type: $type, text: $text, toolName: $toolName)';
}

enum MessageEventType {
  userInput,
  claudeText,
  toolCall,
  toolResult,
  thinking,
  system,
  interactiveMenu,
}
