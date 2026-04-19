import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/raw_ws_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/menu_model.dart';
import '../providers/team_provider.dart';
import '../providers/menu_provider.dart';
import '../services/output_parser.dart';
import '../widgets/agent_panel.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ask_user_card.dart';
import '../widgets/message_input.dart';
import '../widgets/chat_timeline_view.dart';

// Provider do agente selecionado
final _selectedAgentIndexProvider = StateProvider<int>((ref) => 0);

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamNotifierProvider(teamId));
    final selectedIndex = ref.watch(_selectedAgentIndexProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          toolbarHeight: 52,
          title: teamAsync.when(
            data: (t) {
              final agentName = selectedIndex < t.agents.length
                  ? t.agents[selectedIndex].name
                  : '';
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.name, style: AppTextStyles.heading1),
                        if (agentName.isNotEmpty)
                          Text(
                            agentName,
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.neonBlue),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Text('Team', style: AppTextStyles.heading1),
          ),
          iconTheme: const IconThemeData(color: AppColors.neonBlue),
          bottom: TabBar(
            indicatorColor: AppColors.neonBlue,
            indicatorWeight: 2,
            labelColor: AppColors.neonBlue,
            unselectedLabelColor: AppColors.border,
            labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.label,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline, size: 16), text: 'Chat'),
              Tab(icon: Icon(Icons.terminal, size: 16), text: 'Terminal'),
            ],
          ),
        ),
        body: teamAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neonBlue)),
          error: (e, _) =>
              EmptyState(message: 'Erro: $e', icon: Icons.error_outline),
          data: (team) {
            final allAgents = team.agents;
            if (allAgents.isEmpty) {
              return const EmptyState(
                message: 'Nenhum agente encontrado.',
                icon: Icons.smart_toy_outlined,
              );
            }
            final idx = selectedIndex.clamp(0, allAgents.length - 1);
            final selectedAgent = allAgents[idx];

            return Column(
              children: [
                // 🔹 Chips de seleção de agente
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 10, 24, 10),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(allAgents.length, (i) {
                      final agent = allAgents[i];
                      final isSelected = idx == i;
                      return GestureDetector(
                        onTap: () =>
                            ref.read(_selectedAgentIndexProvider.notifier).state =
                                i,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonBlue.withOpacity(0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color:
                                  isSelected ? AppColors.neonBlue : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                agent.isOrchestrator
                                    ? Icons.hub_outlined
                                    : Icons.smart_toy_outlined,
                                color: isSelected
                                    ? AppColors.neonBlue
                                    : AppColors.border,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                agent.name,
                                style: AppTextStyles.label.copyWith(
                                  color: isSelected
                                      ? AppColors.neonBlue
                                      : const Color(0xFF8892a4),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (agent.status == 'active') ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.neonGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const Divider(height: 1, color: Color(0x1A00D4FF)),

                // 🔹 Tab content: Chat | Terminal
                Expanded(
                  child: TabBarView(
                    children: [
                      // ── Aba Chat ──
                      Column(
                        children: [
                          Expanded(
                            child: selectedAgent.sessionName != null &&
                                    selectedAgent.sessionName!.isNotEmpty
                                ? ChatTimelineView(
                                    key: ValueKey(
                                        'chat_${selectedAgent.id}'),
                                    session: selectedAgent.sessionName!,
                                  )
                                : _AgentChatView(
                                    key: ValueKey(
                                        'legacy_${selectedAgent.id}'),
                                    agent: selectedAgent,
                                  ),
                          ),
                          SafeArea(
                            top: false,
                            child: MessageInput(
                              onSend: (msg) {
                                final session = selectedAgent.sessionName;
                                if (session != null && session.isNotEmpty) {
                                  RawWsClient.sendInput(session, msg);
                                }
                                ref
                                    .read(teamNotifierProvider(teamId).notifier)
                                    .sendMessage(msg);
                              },
                              sessionName: selectedAgent.sessionName,
                              onImageUpload: (imageUrl) async {
                                final notifier = ref.read(
                                    teamNotifierProvider(teamId).notifier);
                                await notifier.sendMessage(
                                    'Imagem compartilhada: $imageUrl');
                              },
                            ),
                          ),
                        ],
                      ),

                      // ── Aba Terminal ──
                      Column(
                        children: [
                          Expanded(
                            child: AgentPanel(
                              key: ValueKey('terminal_${selectedAgent.id}'),
                              agent: selectedAgent,
                              expanded: true,
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: MessageInput(
                              onSend: (msg) {
                                final session = selectedAgent.sessionName;
                                if (session != null && session.isNotEmpty) {
                                  RawWsClient.sendInput(session, msg);
                                }
                                ref
                                    .read(teamNotifierProvider(teamId).notifier)
                                    .sendMessage(msg);
                              },
                              sessionName: selectedAgent.sessionName,
                              onImageUpload: (imageUrl) async {
                                final notifier = ref.read(
                                    teamNotifierProvider(teamId).notifier);
                                await notifier.sendMessage(
                                    'Imagem compartilhada: $imageUrl');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// View de chat legada (output bruto via WS) — mantida como fallback.
class _AgentChatView extends StatefulWidget {
  const _AgentChatView({super.key, required this.agent});
  final AgentModel agent;

  @override
  State<_AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<_AgentChatView> {
  final _scrollController = ScrollController();
  List<ParsedMessage> _messages = [];
  InteractiveMenu? _activeMenu;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final session = widget.agent.sessionName;
    if (session == null || session.isEmpty) return;

    RawWsClient.subscribe(session).then((_) {
      _sub = RawWsClient.messages(session).listen((msg) {
        if (!mounted) return;
        final type = msg['type'] as String?;
        if (type == 'output') {
          final raw = msg['data'] as String? ?? '';
          final parsed = parseOutput(raw);
          setState(() => _messages = parsed);
          _scrollToBottom();
        } else if (type == 'interactive_menu') {
          setState(() => _activeMenu = InteractiveMenu.fromJson(msg, session));
        }
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _selectOption(int index) {
    final session = widget.agent.sessionName;
    if (session == null) return;
    RawWsClient.selectOption(session, index,
        currentIndex: _activeMenu?.currentIndex ?? 1);
    setState(() => _activeMenu = null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty && _activeMenu == null) {
      return Center(
        child: Text(
          widget.agent.sessionName != null
              ? 'Conectando ao agente...'
              : 'Agente sem sessão tmux',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _messages.length + (_activeMenu != null ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_activeMenu != null && i == _messages.length) {
          return AskUserCard(menu: _activeMenu!, onSelect: _selectOption);
        }
        return ChatBubble(message: _messages[i]);
      },
    );
  }
}
