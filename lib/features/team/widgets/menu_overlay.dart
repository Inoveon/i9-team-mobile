import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_model.dart';
import '../providers/menu_provider.dart';

class MenuOverlay extends ConsumerWidget {
  const MenuOverlay({
    super.key,
    required this.sessionName,
  });

  final String sessionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider(sessionName));

    return menuAsync.when(
      data: (menu) {
        if (menu == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0a0a0a).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.neonBlue.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.1),
                      blurRadius: 32,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECIONE UMA OPÇÃO:',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.neonBlue,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...menu.options.map(
                      (opt) => _MenuButton(
                        option: opt,
                        onTap: () => selectMenuOption(ref, sessionName, opt.index),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.option,
    required this.onTap,
  });

  final MenuOption option;
  final VoidCallback onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered ? AppColors.neonBlue.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
            color: _hovered ? AppColors.neonBlue.withOpacity(0.12) : Colors.transparent,
          ),
          child: Row(
            children: [
              Text(
                '${widget.option.index}.',
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.neonBlue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.option.label,
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFFe2e8f0),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
