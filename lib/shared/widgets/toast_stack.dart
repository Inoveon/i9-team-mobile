import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 4 kinds visuais — cores espelham os do frontend (`notes/NotesToast.tsx`).
enum ToastKind { info, success, error, warning }

class ToastAction {
  const ToastAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

class ToastItem {
  const ToastItem({
    required this.id,
    required this.kind,
    required this.message,
    this.title,
    this.actions = const [],
  });

  final String id;
  final ToastKind kind;
  final String message;
  final String? title;
  final List<ToastAction> actions;
}

/// Notifier singleton que mantém a pilha de toasts.
/// TTL: 12s com actions, 4s sem.
class ToastController extends StateNotifier<List<ToastItem>> {
  ToastController() : super(const []);

  final Map<String, Timer> _timers = {};
  int _counter = 0;

  String show(
    ToastKind kind,
    String message, {
    String? title,
    List<ToastAction> actions = const [],
    Duration? ttl,
  }) {
    final id = 't${DateTime.now().millisecondsSinceEpoch}-${++_counter}';
    final item = ToastItem(
      id: id,
      kind: kind,
      message: message,
      title: title,
      actions: actions,
    );
    state = [...state, item];
    final timeout =
        ttl ?? (actions.isNotEmpty ? const Duration(seconds: 12) : const Duration(seconds: 4));
    _timers[id] = Timer(timeout, () => dismiss(id));
    return id;
  }

  void dismiss(String id) {
    _timers.remove(id)?.cancel();
    state = state.where((t) => t.id != id).toList();
  }

  // Atalhos semânticos
  String info(String msg, {String? title, List<ToastAction> actions = const []}) =>
      show(ToastKind.info, msg, title: title, actions: actions);
  String success(String msg, {String? title, List<ToastAction> actions = const []}) =>
      show(ToastKind.success, msg, title: title, actions: actions);
  String error(String msg, {String? title, List<ToastAction> actions = const []}) =>
      show(ToastKind.error, msg, title: title, actions: actions);
  String warning(String msg, {String? title, List<ToastAction> actions = const []}) =>
      show(ToastKind.warning, msg, title: title, actions: actions);

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// Provider singleton — use via `ref.read(toastProvider.notifier).success('msg')`.
final toastProvider =
    StateNotifierProvider<ToastController, List<ToastItem>>(
  (ref) => ToastController(),
);

/// Overlay que renderiza a pilha de toasts no canto inferior direito.
/// Deve ser colocado em nível de root (ex: no `App.build`).
class ToastStack extends ConsumerWidget {
  const ToastStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in toasts)
              _ToastCard(
                key: ValueKey(t.id),
                item: t,
                onDismiss: () =>
                    ref.read(toastProvider.notifier).dismiss(t.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.item, required this.onDismiss});

  final ToastItem item;
  final VoidCallback onDismiss;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({Color bg, Color border, Color fg, IconData icon}) get _style =>
      switch (widget.item.kind) {
        ToastKind.info => (
            bg: AppColors.neonBlue.withOpacity(0.10),
            border: AppColors.neonBlue.withOpacity(0.45),
            fg: AppColors.neonBlue,
            icon: Icons.info_outline,
          ),
        ToastKind.success => (
            bg: AppColors.neonGreen.withOpacity(0.10),
            border: AppColors.neonGreen.withOpacity(0.45),
            fg: AppColors.neonGreen,
            icon: Icons.check_circle_outline,
          ),
        ToastKind.error => (
            bg: AppColors.neonRed.withOpacity(0.12),
            border: AppColors.neonRed.withOpacity(0.5),
            fg: AppColors.neonRed,
            icon: Icons.error_outline,
          ),
        ToastKind.warning => (
            bg: AppColors.neonYellow.withOpacity(0.10),
            border: AppColors.neonYellow.withOpacity(0.5),
            fg: AppColors.neonYellow,
            icon: Icons.warning_amber_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: s.fg.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s.icon, color: s.fg, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.item.title != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                widget.item.title!,
                                style: AppTextStyles.label.copyWith(
                                  color: s.fg,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Text(
                            widget.item.message,
                            style: AppTextStyles.body.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onDismiss,
                    ),
                  ],
                ),
                if (widget.item.actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final a in widget.item.actions)
                        TextButton(
                          onPressed: () {
                            a.onTap();
                            widget.onDismiss();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: a.primary
                                ? s.fg.withOpacity(0.14)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: s.fg.withOpacity(a.primary ? 0.5 : 0.25),
                              ),
                            ),
                          ),
                          child: Text(
                            a.label,
                            style: AppTextStyles.label.copyWith(
                              color: s.fg,
                              fontWeight: a.primary
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
