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
import '../features/chat/presentation/screens/conversations_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/chat/presentation/screens/league_chat_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/leagues/presentation/screens/league_detail_screen.dart';

/// Configuração de rotas do app
class AppRouter {
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
        ],
      ),

      // ── Telas secundárias (AppBar próprio, sem bottom nav) ───
      GoRoute(
        path: '/leagues/create',
        builder: (context, state) => const CreateLeagueScreen(),
      ),
      GoRoute(
        path: '/leagues/:id',
        builder: (context, state) => LeagueDetailScreen(
          leagueId: state.pathParameters['id']!,
        ),
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
        builder: (context, state) => PredictionScreen(
          raceId: state.pathParameters['raceId']!,
        ),
      ),
      GoRoute(
        path: '/predictions-view/:raceId',
        builder: (context, state) => PredictionViewScreen(
          raceId: state.pathParameters['raceId']!,
        ),
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
        path: '/messages',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/chat/:friendId',
        builder: (context, state) => ChatScreen(
          friendId: state.pathParameters['friendId']!,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
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
        path: '/admin/results',
        builder: (context, state) =>
            const AdminShellScreen(section: 'results'),
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
