import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/team_provider.dart';
import '../providers/menu_provider.dart';
import './menu_overlay.dart';

class AgentPanel extends StatefulWidget {
  const AgentPanel({super.key, required this.agent, this.expanded = false});

  final AgentModel agent;
  final bool expanded;

  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(AgentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agent.outputLines != oldWidget.agent.outputLines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  AgentStatus get _status => switch (widget.agent.status) {
        'active' => AgentStatus.active,
        'idle' => AgentStatus.idle,
        'error' => AgentStatus.error,
        _ => AgentStatus.offline,
      };

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.agent.isOrchestrator)
                const Icon(Icons.hub_outlined, color: AppColors.neonPurple, size: 18)
              else
                const Icon(Icons.smart_toy_outlined, color: AppColors.neonBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.agent.name, style: AppTextStyles.heading2, overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(status: _status),
            ],
          ),
          if (widget.agent.role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.agent.role, style: AppTextStyles.label),
          ],
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: widget.expanded ? 300 : 150,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: widget.agent.outputLines.isEmpty
                    ? Center(child: Text('Aguardando output...', style: AppTextStyles.bodyMuted))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.agent.outputLines.length,
                        itemBuilder: (ctx, i) => Text(
                          widget.agent.outputLines[i],
                          style: AppTextStyles.mono,
                        ),
                      ),
              ),
              if (widget.agent.sessionName != null)
                Consumer(
                  builder: (ctx, ref, _) {
                    final menuStream = ref.watch(menuProvider(widget.agent.sessionName!));
                    return menuStream.when(
                      data: (menu) {
                        if (menu == null) return const SizedBox.shrink();
                        return MenuOverlay(sessionName: widget.agent.sessionName!);
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
