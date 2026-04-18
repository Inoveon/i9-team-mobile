/// Opção individual do menu interativo.
class MenuOption {
  const MenuOption({
    required this.index,
    required this.label,
    this.current = false,
  });

  final int index;
  final String label;
  final bool current;

  factory MenuOption.fromJson(Map<String, dynamic> json) => MenuOption(
        index: (json['index'] as int?) ?? 0,
        label: (json['label'] as String?) ?? '',
        current: (json['current'] as bool?) ?? false,
      );
}

/// Menu interativo recebido do backend via WebSocket.
class InteractiveMenu {
  const InteractiveMenu({
    required this.session,
    required this.options,
    required this.currentIndex,
  });

  final String session;
  final List<MenuOption> options;
  final int currentIndex;

  factory InteractiveMenu.fromJson(
    Map<String, dynamic> json,
    String sessionId,
  ) =>
      InteractiveMenu(
        session: sessionId,
        options: ((json['options'] as List?) ?? [])
            .map((o) => MenuOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        currentIndex: (json['currentIndex'] as int?) ?? 1,
      );
}
