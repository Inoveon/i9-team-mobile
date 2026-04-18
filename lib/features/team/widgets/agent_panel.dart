import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
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
  Timer? _pollTimer;
  List<String> _outputLines = [];

  @override
  void initState() {
    super.initState();
    _outputLines = List.from(widget.agent.outputLines);
    if (widget.agent.sessionName != null && widget.agent.sessionName!.isNotEmpty) {
      _startPolling();
    }
  }

  @override
  void didUpdateWidget(AgentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reiniciar polling se agente mudou
    if (widget.agent.id != oldWidget.agent.id) {
      _pollTimer?.cancel();
      _outputLines = List.from(widget.agent.outputLines);
      if (widget.agent.sessionName != null && widget.agent.sessionName!.isNotEmpty) {
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _fetchOutput(); // busca imediatamente
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchOutput());
  }

  Future<void> _fetchOutput() async {
    final session = widget.agent.sessionName;
    if (session == null || session.isEmpty) return;
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/tmux/capture/$session', queryParameters: {'lines': '80'});
      final raw = (response.data as Map?)?['output'] as String? ?? '';
      if (raw.isEmpty) return;
      final lines = raw
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _outputLines = lines;
      });
      // Auto-scroll para o final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (_) {
      // silencia erros de rede
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
    final lines = _outputLines.isNotEmpty ? _outputLines : widget.agent.outputLines;

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
                height: widget.expanded ? 300 : 200,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: lines.isEmpty
                    ? Center(child: Text('Aguardando output...', style: AppTextStyles.bodyMuted))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: lines.length,
                        itemBuilder: (ctx, i) => Text(
                          lines[i],
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
