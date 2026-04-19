import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Card colapsável que agrupa uma tool call com seu resultado.
class ToolCallCard extends StatefulWidget {
  const ToolCallCard({
    super.key,
    required this.toolName,
    this.args,
    this.result,
    this.toolId,
  });

  final String toolName;
  final String? args;
  final String? result;
  final String? toolId;

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _expanded = false;

  IconData get _toolIcon {
    switch (widget.toolName.toLowerCase()) {
      case 'bash':
        return Icons.terminal;
      case 'read':
        return Icons.description_outlined;
      case 'write':
        return Icons.edit_note;
      case 'edit':
        return Icons.edit_outlined;
      case 'glob':
        return Icons.search;
      case 'grep':
        return Icons.manage_search;
      case 'webfetch':
        return Icons.language;
      case 'agent':
        return Icons.smart_toy_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = widget.result != null && widget.result!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 56, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: const Color(0x0D00D4FF),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header clicável
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(_toolIcon, size: 14, color: AppColors.neonBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usou ${widget.toolName}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hasResult)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.neonBlue.withOpacity(0.6),
                    ),
                ],
              ),
            ),
          ),

          // Body expansível
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0x1A00D4FF)),
            if (widget.args != null && widget.args!.isNotEmpty)
              _Section(
                label: 'Input',
                content: widget.args!,
                color: AppColors.neonBlue,
              ),
            if (hasResult)
              _Section(
                label: 'Output',
                content: widget.result!,
                color: AppColors.neonGreen,
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.content,
    required this.color,
  });

  final String label;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Trunca output longo
    final display = content.length > 600
        ? '${content.substring(0, 600)}\n... (truncado)'
        : content;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: color.withOpacity(0.7),
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              display,
              style: AppTextStyles.body.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: color.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
