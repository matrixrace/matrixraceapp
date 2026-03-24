import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/main_shell.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/leagues/presentation/screens/leagues_screen.dart';
import '../features/rankings/presentation/screens/rankings_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/predictions/presentation/screens/prediction_screen.dart';
import '../features/admin/presentation/screens/admin_shell_screen.dart';
import '../features/predictions/presentation/screens/prediction_view_screen.dart';
import '../features/leagues/presentation/screens/create_league_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/friends/presentation/screens/friends_screen.dart';
import '../features/chat/presentation/screens/league_chat_screen.dart';
import '../features/chat/presentation/screens/messaging_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/leagues/presentation/screens/league_detail_screen.dart';
import '../features/f1results/presentation/screens/f1_results_screen.dart';
import '../features/profile/presentation/screens/user_profile_screen.dart';
import '../features/admin/presentation/screens/admin_user_leagues_screen.dart';
import '../features/how_it_works/presentation/screens/how_it_works_screen.dart';
import '../features/live/presentation/screens/live_screen.dart';
import '../features/news/presentation/screens/news_screen.dart';
import '../features/leagues/presentation/screens/join_league_screen.dart';

/// Configuração de rotas do app
class AppRouter {
  /// Transição suave de fade para navegação entre telas secundárias
  static CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // ── Login e Cadastro (sem shell) ─────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Telas principais com shell compartilhado ─────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/leagues',
            builder: (context, state) => const LeaguesScreen(),
          ),
          GoRoute(
            path: '/rankings',
            builder: (context, state) => const RankingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/live',
            builder: (context, state) => const LiveScreen(),
          ),
          GoRoute(
            path: '/news',
            builder: (context, state) => const NewsScreen(),
          ),
        ],
      ),

      // Histórico de resultados F1 (removido do shell, agora é rota secundária)
      GoRoute(
        path: '/f1-results',
        pageBuilder: (context, state) => _fadeTransition(state, const F1ResultsScreen()),
      ),

      // ── Telas secundárias (AppBar próprio, sem bottom nav) ───
      GoRoute(
        path: '/leagues/create',
        pageBuilder: (context, state) => _fadeTransition(state, const CreateLeagueScreen()),
      ),
      GoRoute(
        path: '/leagues/:id',
        pageBuilder: (context, state) => _fadeTransition(state, LeagueDetailScreen(
          leagueId: state.pathParameters['id']!,
          isMemberHint: state.extra as bool?,
        )),
      ),
      GoRoute(
        path: '/leagues/:id/chat',
        builder: (context, state) => LeagueChatScreen(
          leagueId: state.pathParameters['id']!,
          leagueName: state.uri.queryParameters['name'] ?? 'Liga',
        ),
      ),
      GoRoute(
        path: '/predictions/:raceId',
        pageBuilder: (context, state) => _fadeTransition(state, PredictionScreen(
          raceId: state.pathParameters['raceId']!,
        )),
      ),
      GoRoute(
        path: '/predictions-view/:raceId',
        pageBuilder: (context, state) => _fadeTransition(state, PredictionViewScreen(
          raceId: state.pathParameters['raceId']!,
        )),
      ),
      GoRoute(
        path: '/predictions-edit-order/:raceId',
        builder: (context, state) => PredictionScreen(
          raceId: state.pathParameters['raceId']!,
          editOrderOnly: true,
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/messaging',
        builder: (context, state) => MessagingScreen(
          initialFriendId: state.uri.queryParameters['friendId'],
          initialGroupId: state.uri.queryParameters['groupId'],
        ),
      ),
      GoRoute(
        path: '/messages',
        redirect: (context, state) => '/messaging',
      ),
      GoRoute(
        path: '/chat/:friendId',
        redirect: (context, state) =>
            '/messaging?friendId=${state.pathParameters['friendId']}',
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => _fadeTransition(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/how-it-works',
        builder: (context, state) => const HowItWorksScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) => JoinLeagueScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/users/:userId',
        builder: (context, state) => UserProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),

      // ── Painel Admin ──────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            const AdminShellScreen(section: 'dashboard'),
      ),
      GoRoute(
        path: '/admin/races',
        builder: (context, state) =>
            const AdminShellScreen(section: 'races'),
      ),
      GoRoute(
        path: '/admin/drivers',
        builder: (context, state) =>
            const AdminShellScreen(section: 'drivers'),
      ),
      GoRoute(
        path: '/admin/teams',
        builder: (context, state) =>
            const AdminShellScreen(section: 'teams'),
      ),
      GoRoute(
        path: '/admin/leagues',
        builder: (context, state) =>
            const AdminShellScreen(section: 'leagues'),
      ),
      GoRoute(
        path: '/admin/ai-order',
        builder: (context, state) =>
            const AdminShellScreen(section: 'ai_order'),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) =>
            const AdminShellScreen(section: 'users'),
      ),
      GoRoute(
        path: '/admin/live-results',
        builder: (context, state) =>
            const AdminShellScreen(section: 'live_results'),
      ),
      GoRoute(
        path: '/admin/user-leagues',
        builder: (context, state) => const AdminUserLeaguesScreen(),
      ),
    ],

    // Tela de erro
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Página não encontrada',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    ),
  );
}
