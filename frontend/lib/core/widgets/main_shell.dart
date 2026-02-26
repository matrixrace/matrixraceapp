import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Shell compartilhado entre as 4 telas principais:
/// Início, Ligas, Ranking e Perfil.
/// Fornece AppBar consistente e BottomNavigationBar em todas elas.
class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ApiClient _api = ApiClient();
  int _unreadCount = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
    _checkAdmin();
  }

  Future<void> _loadNotificationCount() async {
    final res = await _api.get('/notifications');
    if (mounted && res.success && res.data != null) {
      final count = res.data['unreadCount'] as int? ?? 0;
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _checkAdmin() async {
    final res = await _api.get('/auth/me');
    if (mounted && res.success && res.data != null) {
      setState(() => _isAdmin = res.data['isAdmin'] == true);
    }
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/leagues')) return 1;
    if (loc.startsWith('/rankings')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.flag_rounded,
                  size: 24,
                  color: AppTheme.primaryRed,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Matrix Race'),
          ],
        ),
        actions: [
          // Sino de notificações com badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  context.push('/notifications').then((_) => _loadNotificationCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Menu do usuário
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.person),
                  onSelected: (value) {
                    if (value == 'logout') {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                    } else if (value == 'admin') {
                      context.go('/admin');
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Text(state.user.displayName ?? 'Perfil'),
                    ),
                    if (_isAdmin)
                      const PopupMenuItem(
                        value: 'admin',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Painel Admin'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Sair'),
                    ),
                  ],
                );
              }
              return TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Entrar'),
              );
            },
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) return const SizedBox.shrink();
          final idx = _selectedIndex(context);
          return NavigationBar(
            backgroundColor: AppTheme.cardBackground,
            selectedIndex: idx,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/leagues');
                case 2:
                  context.go('/rankings');
                case 3:
                  context.go('/profile');
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Ligas',
              ),
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: 'Ranking',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          );
        },
      ),
    );
  }
}
