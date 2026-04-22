import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_colors.dart';
import 'features/config/screens/config_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/team/screens/team_screen.dart';
import 'shared/widgets/toast_stack.dart';

class App extends StatelessWidget {
  const App({super.key, this.initialRoute = '/'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: initialRoute,
      routes: [
        GoRoute(path: '/', builder: (ctx, _) => const HomeScreen()),
        GoRoute(
          path: '/team/:id',
          builder: (ctx, state) => TeamScreen(
            teamId: state.pathParameters['id']!,
            initialTab: state.uri.queryParameters['tab'],
            initialNote: state.uri.queryParameters['note'],
          ),
        ),
        // Compatibilidade — rota antiga redireciona pra aba Notas da TeamScreen
        GoRoute(
          path: '/team/:id/notes',
          redirect: (ctx, state) => '/team/${state.pathParameters['id']!}?tab=notes',
        ),
        GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
        GoRoute(path: '/config', builder: (ctx, _) => const ConfigScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'i9 Team',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.neonBlue,
          secondary: AppColors.neonPurple,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const ToastStack(),
        ],
      ),
    );
  }
}
