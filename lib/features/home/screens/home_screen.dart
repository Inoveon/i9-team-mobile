import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../providers/health_provider.dart';
import '../providers/teams_provider.dart';
import '../widgets/new_team_dialog.dart';
import '../widgets/team_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(teamsNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('i9 Team', style: AppTextStyles.heading1),
        actions: [
          const _BackendHealthDot(),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.neonBlue),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
        error: (e, _) => EmptyState(
          message: 'Erro ao carregar teams\n$e',
          icon: Icons.error_outline,
          action: () => ref.read(teamsNotifierProvider.notifier).refresh(),
          actionLabel: 'Tentar novamente',
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return const EmptyState(
              message: 'Nenhum team encontrado.\nVerifique a URL do backend nas configuracoes.',
              icon: Icons.groups_outlined,
            );
          }
          return RefreshIndicator(
            color: AppColors.neonBlue,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.read(teamsNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: teams.length,
              itemBuilder: (ctx, i) => TeamCard(
                team: teams[i],
                onTap: () => context.push('/team/${teams[i].id}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonPurple,
        tooltip: 'Novo team',
        onPressed: () => _openNewTeamWizard(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _openNewTeamWizard(BuildContext context) async {
    final result = await NewTeamDialog.show(context);
    if (result == null || !mounted) return;
    final toast = ref.read(toastProvider.notifier);
    try {
      final newId = await ref.read(teamsNotifierProvider.notifier).createTeam(
            name: result.name,
            description: result.description,
            agents: result.agents,
          );
      toast.success('Team "${result.name}" criado');
      if (!mounted) return;
      context.push('/team/$newId');
    } catch (e) {
      toast.error('Falha ao criar team: $e');
    }
  }
}

/// Dot 8×8 no AppBar indicando se o backend responde em `/health`.
/// Pulsa suavemente quando online; fica estático vermelho quando offline.
class _BackendHealthDot extends ConsumerStatefulWidget {
  const _BackendHealthDot();

  @override
  ConsumerState<_BackendHealthDot> createState() => _BackendHealthDotState();
}

class _BackendHealthDotState extends ConsumerState<_BackendHealthDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(backendHealthProvider);
    final online = healthAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final color = online ? AppColors.neonGreen : AppColors.neonRed;
    final tooltip = online ? 'Backend online' : 'Backend offline';

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, left: 12),
        child: Center(
          child: online
              ? FadeTransition(
                  opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_pulse),
                  child: _dot(color),
                )
              : _dot(color),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 6),
          ],
        ),
      );
}
