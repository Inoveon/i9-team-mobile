import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/teams_provider.dart';
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
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
