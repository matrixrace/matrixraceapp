import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import 'admin_dashboard_screen.dart';
import 'admin_races_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_teams_screen.dart';
import 'admin_leagues_screen.dart';
import 'admin_ai_order_screen.dart';
import 'admin_users_screen.dart';
import 'admin_live_results_screen.dart';

/// Painel Administrativo — container com sidebar responsiva
/// Em desktop (>=900px): sidebar fixa colapsável
/// Em mobile (<900px): Drawer
class AdminShellScreen extends StatefulWidget {
  final String section;
  const AdminShellScreen({super.key, this.section = 'dashboard'});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

enum _AdminState { loading, loginForm, accessDenied, panel }

class _AdminShellScreenState extends State<AdminShellScreen> {
  final ApiClient _api = ApiClient();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _AdminState _state = _AdminState.loading;
  late String _currentSection;
  bool _sidebarCollapsed = false;

  // Login form
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loggingIn = false;
  String? _loginError;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.section;
    _checkAdmin();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    setState(() => _state = _AdminState.loading);

    final firebaseUser = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;

    if (firebaseUser == null) {
      setState(() => _state = _AdminState.loginForm);
      return;
    }

    final res = await _api.get('/auth/me');
    if (!mounted) return;

    if (res.success && res.data != null && res.data['isAdmin'] == true) {
      setState(() => _state = _AdminState.panel);
    } else {
      setState(() => _state = _AdminState.accessDenied);
    }
  }

  Future<void> _doLogin() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() { _loggingIn = true; _loginError = null; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await _checkAdmin();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loginError = _authError(e.code);
          _loggingIn = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      _emailCtrl.clear();
      _passCtrl.clear();
      setState(() => _state = _AdminState.loginForm);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':      return 'Usuário não encontrado';
      case 'wrong-password':      return 'Senha incorreta';
      case 'invalid-credential':  return 'Email ou senha incorretos';
      case 'too-many-requests':   return 'Muitas tentativas. Aguarde.';
      default:                    return 'Erro: $code';
    }
  }

  static const _sections = [
    {'key': 'dashboard',     'label': 'Dashboard',  'icon': Icons.dashboard},
    {'key': 'races',         'label': 'Corridas',   'icon': Icons.flag},
    {'key': 'live_results',  'label': 'Live',       'icon': Icons.live_tv},
    {'key': 'drivers',       'label': 'Pilotos',    'icon': Icons.person},
    {'key': 'teams',         'label': 'Equipes',    'icon': Icons.groups},
    {'key': 'leagues',       'label': 'Ligas Of.',  'icon': Icons.verified},
    {'key': 'ai_order',      'label': 'Palpite IA', 'icon': Icons.auto_awesome},
    {'key': 'users',         'label': 'Usuários',   'icon': Icons.manage_accounts},
  ];

  Widget _buildContent() {
    switch (_currentSection) {
      case 'races':        return const AdminRacesScreen();
      case 'live_results': return const AdminLiveResultsScreen();
      case 'drivers':      return const AdminDriversScreen();
      case 'teams':        return const AdminTeamsScreen();
      case 'leagues':      return const AdminLeaguesScreen();
      case 'ai_order':     return const AdminAiOrderScreen();
      case 'users':        return const AdminUsersScreen();
      default:             return const AdminDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AdminState.loading:
        return _buildLoading();
      case _AdminState.loginForm:
        return _buildLoginForm();
      case _AdminState.accessDenied:
        return _buildAccessDenied();
      case _AdminState.panel:
        return _buildPanel();
    }
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
    );
  }

  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryGreen, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso Administrativo',
                style: AppTheme.displayStyle(fontSize: 20),
              ),
              const SizedBox(height: 4),
              const Text(
                'Matrix Race Arena',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _doLogin(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                onSubmitted: (_) => _doLogin(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),

              if (_loginError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCF6679).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCF6679).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFCF6679), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loginError!,
                          style: const TextStyle(color: Color(0xFFCF6679), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loggingIn ? null : _doLogin,
                  icon: _loggingIn
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(_loggingIn ? 'Entrando...' : 'Entrar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCF6679).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, color: Color(0xFFCF6679), size: 40),
              ),
              const SizedBox(height: 16),
              Text('Acesso Negado', style: AppTheme.displayStyle(fontSize: 20)),
              const SizedBox(height: 8),
              const Text(
                'Sua conta não tem permissão de administrador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair e tentar outro login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(isWide: true),
                Expanded(
                  child: Container(
                    color: AppTheme.darkBackground,
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile: usa Drawer
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  _sections.firstWhere((s) => s['key'] == _currentSection)['label'] as String,
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            backgroundColor: AppTheme.cardBackground,
            child: _buildSidebar(isWide: false),
          ),
          body: Container(
            color: AppTheme.darkBackground,
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildSidebar({required bool isWide}) {
    final collapsedWidth = 64.0;
    final expandedWidth = 220.0;
    final width = isWide ? (_sidebarCollapsed ? collapsedWidth : expandedWidth) : expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isWide ? width : double.infinity,
      color: AppTheme.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: 20,
              horizontal: _sidebarCollapsed && isWide ? 12 : 16,
            ),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
            ),
            child: _sidebarCollapsed && isWide
                ? const Center(
                    child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text('ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                      Text('Matrix Race', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
          ),

          // Toggle collapse (só em desktop)
          if (isWide)
            InkWell(
              onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.end,
                  children: [
                    Icon(
                      _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    if (!_sidebarCollapsed) ...[
                      const SizedBox(width: 4),
                      const Text('Recolher', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ),

          // Logout
          InkWell(
            onTap: _logout,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _sidebarCollapsed && isWide ? 12 : 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: _sidebarCollapsed && isWide ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.logout, size: 16, color: AppTheme.textSecondary),
                  if (!(_sidebarCollapsed && isWide)) ...[
                    const SizedBox(width: 8),
                    const Text('Sair', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 8),

          // Itens de navegação
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _sections.map((s) {
                final isActive = _currentSection == s['key'];
                final icon = s['icon'] as IconData;
                final label = s['label'] as String;

                return Tooltip(
                  message: _sidebarCollapsed && isWide ? label : '',
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentSection = s['key'] as String);
                      // Fecha drawer em mobile
                      if (!isWide && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: _sidebarCollapsed && isWide ? 6 : 8,
                        vertical: 2,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: _sidebarCollapsed && isWide ? 0 : 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isActive ? Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)) : null,
                      ),
                      child: _sidebarCollapsed && isWide
                          ? Center(
                              child: Icon(icon, size: 20, color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary),
                            )
                          : Row(
                              children: [
                                Icon(icon, size: 18, color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isActive ? AppTheme.primaryGreen : AppTheme.textPrimary,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
