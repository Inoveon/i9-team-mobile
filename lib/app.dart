import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_colors.dart';
import 'features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/team/screens/team_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const HomeScreen()),
    GoRoute(path: '/team/:id', builder: (ctx, state) => TeamScreen(teamId: state.pathParameters['id']!)),
    GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'i9 Team',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          background: AppColors.bg,
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
      routerConfig: _router,
    );
  }
}
