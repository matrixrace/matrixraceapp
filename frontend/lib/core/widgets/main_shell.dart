import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../tutorial/tutorial_bloc.dart';
import '../tutorial/tutorial_step.dart';
import '../tutorial/tutorial_overlay.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../services/pending_redirect_service.dart';

/// Shell compartilhado entre as telas principais.
/// Fornece AppBar consistente, BottomNavigationBar e TutorialOverlay.
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
    _showWelcomeIfNeeded();
    _checkPendingRedirect();
  }

  /// Verifica se há um redirect pendente (ex: link de convite de liga).
  /// Cobre o caso do Google Sign-In que recarrega a página inteira.
  Future<void> _checkPendingRedirect() async {
    final pendingUrl = await PendingRedirectService.consumeRedirect();
    if (pendingUrl != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          context.go(pendingUrl);
        }
      });
    }
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

  Future<void> _showWelcomeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(TutorialBloc.keyWelcomeShown) ?? false;
    if (shown || !mounted) return;

    await prefs.setBool(TutorialBloc.keyWelcomeShown, true);

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_motorsports,
                      size: 48,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bem-vindo ao Matrix Race!',
                    style: AppTheme.displayStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Vamos te mostrar como tudo funciona.\n'
                    'Dicas vão aparecer em cada tela para te guiar pelos principais recursos.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 16,
                          color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Você pode desativar as dicas no menu do usuário',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Começar!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/live')) return 1;
    if (loc.startsWith('/leagues')) return 2;
    if (loc.startsWith('/rankings')) return 3;
    if (loc.startsWith('/news')) return 4;
    if (loc.startsWith('/profile')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo_banner.png',
                height: 76,
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              // Botão "Como Funciona"
              IconButton(
                key: TutorialKeys.appBarHelp,
                icon: const Icon(Icons.help_outline, size: 22),
                tooltip: 'Como Funciona',
                onPressed: () => context.push('/how-it-works'),
              ),
              // Sino de notificações com badge
              _buildNotificationBell(),
              // Menu do usuário
              _buildUserMenu(),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppTheme.borderSubtle,
              ),
            ),
          ),
          body: widget.child,
          bottomNavigationBar: AppBottomNav(
            key: TutorialKeys.bottomNav,
            selectedIndex: _selectedIndex(context),
          ),
        ),
        const TutorialOverlay(),
      ],
    );
  }

  Widget _buildNotificationBell() {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Stack(
        key: TutorialKeys.appBarNotifications,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {
              context.push('/notifications').then((_) => _loadNotificationCount());
            },
          ),
          if (_unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
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
    );
  }

  Widget _buildUserMenu() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          return BlocBuilder<TutorialBloc, TutorialState>(
            builder: (context, tutState) {
              return PopupMenuButton<String>(
                key: TutorialKeys.appBarMenu,
                icon: const Icon(Icons.person, size: 22),
                onSelected: (value) {
                  if (value == 'logout') {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  } else if (value == 'admin') {
                    context.go('/admin');
                  } else if (value == 'profile') {
                    context.go('/profile');
                  } else if (value == 'tutorial_toggle') {
                    context.read<TutorialBloc>().add(
                      TutorialToggleEnabled(!tutState.tutorialsEnabled),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Text(authState.user.displayName ?? 'Perfil'),
                  ),
                  PopupMenuItem(
                    value: 'tutorial_toggle',
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: tutState.tutorialsEnabled
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(tutState.tutorialsEnabled
                            ? 'Desativar Dicas'
                            : 'Ativar Dicas'),
                      ],
                    ),
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
            },
          );
        }
        return TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Entrar'),
        );
      },
    );
  }
}
