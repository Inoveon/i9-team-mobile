/// Parseia raw tmux output em blocos de texto limpo para exibição chat-style.
library;

import 'dart:convert';

// Remove códigos ANSI de escape (cores, cursor, etc.)
final _ansiRe = RegExp(r'\x1b\[[0-9;]*[mGKHFJABCDsuhlr]|\x1b\[?\d*[A-Z]|\x1b[=>]');

// Linhas de "ruído" do terminal que não devemos mostrar
final _noiseRe = RegExp(
  r'(^\s*$'
  r'|^[\u2500-\u257F\u250C\u2510\u2514\u2518\u251C\u2524\u252C\u2534\u253C\u2550-\u256C]' // box-drawing
  r'|^\s*[●○◉►❯✔✘△·]\s*$'                          // só marcadores
  r'|Esc to|↑.*↓|Enter to|Press.*key'               // footers de menu
  r'|^\s*\d+\.\s*$'                                  // só número
  r'|\[K\]|\[H\]|Remote Control'                     // artefatos de terminal
  r')',
  caseSensitive: false,
);

// Detecta início de bloco do assistente
final _assistantStartRe = RegExp(r'^[╭┌]');
final _assistantEndRe = RegExp(r'^[╰└]');

// Tool use / thinking: pula esses blocos
final _toolRe = RegExp(
  r'(^◆\s|^●\s|^\s*<\w+>|Tool:|Thinking\.\.\.|ToolUse:|^·\s)',
  caseSensitive: false,
);

// Mensagem do usuário
final _humanRe = RegExp(r'^(Human:|>\s|You:|User:)', caseSensitive: false);

class ParsedMessage {
  final String text;
  final bool isAssistant; // false = usuário
  const ParsedMessage(this.text, {this.isAssistant = true});
}

List<ParsedMessage> parseOutput(String raw) {
  // Remove ANSI
  final clean = raw.replaceAll(_ansiRe, '');

  final lines = const LineSplitter().convert(clean);
  final messages = <ParsedMessage>[];

  final buffer = StringBuffer();
  bool inAssistantBlock = false;
  bool skipBlock = false;

  void flush({bool isAssistant = true}) {
    final text = buffer.toString().trim();
    buffer.clear();
    if (text.isEmpty) return;
    messages.add(ParsedMessage(text, isAssistant: isAssistant));
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();

    // Ignora ruído
    if (_noiseRe.hasMatch(line)) {
      if (inAssistantBlock) buffer.writeln(line);
      continue;
    }

    // Início de bloco assistente (╭─ ou ┌─)
    if (_assistantStartRe.hasMatch(line)) {
      flush();
      inAssistantBlock = true;
      skipBlock = false;
      continue;
    }

    // Fim de bloco assistente
    if (_assistantEndRe.hasMatch(line) && inAssistantBlock) {
      inAssistantBlock = false;
      flush(isAssistant: true);
      continue;
    }

    // Dentro de bloco: pula tool use / thinking
    if (inAssistantBlock) {
      if (_toolRe.hasMatch(line)) {
        skipBlock = true;
        continue;
      }
      if (skipBlock && line.isEmpty) skipBlock = false;
      if (!skipBlock && line.isNotEmpty) buffer.writeln(line);
      continue;
    }

    // Mensagem do usuário
    if (_humanRe.hasMatch(line)) {
      flush();
      final text = line.replaceFirst(_humanRe, '').trim();
      if (text.isNotEmpty) {
        messages.add(ParsedMessage(text, isAssistant: false));
      }
      continue;
    }

    // Texto fora de bloco: acumula como assistente se tiver conteúdo
    if (line.isNotEmpty && !_toolRe.hasMatch(line)) {
      buffer.writeln(line);
    } else if (line.isEmpty && buffer.isNotEmpty) {
      flush(isAssistant: true);
    }
  }

  flush(isAssistant: true);
  return messages;
}
