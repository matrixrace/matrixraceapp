import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import 'admin_dashboard_screen.dart';
import 'admin_races_screen.dart';
import 'admin_results_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_teams_screen.dart';
import 'admin_leagues_screen.dart';

/// Painel Administrativo — container com sidebar de navegação
/// Acessível apenas pelo admin. Possui login próprio na mesma página.
class AdminShellScreen extends StatefulWidget {
  final String section;
  const AdminShellScreen({super.key, this.section = 'dashboard'});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

// Estados internos do painel
enum _AdminState { loading, loginForm, accessDenied, panel }

class _AdminShellScreenState extends State<AdminShellScreen> {
  final ApiClient _api = ApiClient();
  _AdminState _state = _AdminState.loading;
  late String _currentSection;

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

    // Aguarda Firebase restaurar o estado de autenticação
    final firebaseUser = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;

    if (firebaseUser == null) {
      // Não está logado — mostra formulário de login admin
      setState(() => _state = _AdminState.loginForm);
      return;
    }

    // Está logado — verifica se é admin
    final res = await _api.get('/auth/me');
    if (!mounted) return;

    if (res.success && res.data != null && res.data['isAdmin'] == true) {
      setState(() => _state = _AdminState.panel);
    } else {
      // Logado mas não é admin
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
      // Re-verifica após login
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
    {'key': 'dashboard', 'label': 'Dashboard',  'icon': Icons.dashboard},
    {'key': 'races',     'label': 'Corridas',   'icon': Icons.flag},
    {'key': 'results',   'label': 'Resultados', 'icon': Icons.emoji_events},
    {'key': 'drivers',   'label': 'Pilotos',    'icon': Icons.person},
    {'key': 'teams',     'label': 'Equipes',    'icon': Icons.groups},
    {'key': 'leagues',   'label': 'Ligas Of.',  'icon': Icons.verified},
  ];

  Widget _buildContent() {
    switch (_currentSection) {
      case 'races':   return const AdminRacesScreen();
      case 'results': return const AdminResultsScreen();
      case 'drivers': return const AdminDriversScreen();
      case 'teams':   return const AdminTeamsScreen();
      case 'leagues': return const AdminLeaguesScreen();
      default:        return const AdminDashboardScreen();
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

  // ── Loading ────────────────────────────────────────────────
  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRed)),
    );
  }

  // ── Formulário de Login Admin ──────────────────────────────
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / Título
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryRed, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Acesso Administrativo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Matrix Race Arena',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              // Email
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

              // Senha
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

              // Erro de login
              if (_loginError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.primaryRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loginError!,
                          style: const TextStyle(color: AppTheme.primaryRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Botão entrar
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

  // ── Acesso Negado ──────────────────────────────────────────
  Widget _buildAccessDenied() {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: AppTheme.primaryRed, size: 48),
              const SizedBox(height: 16),
              const Text('Acesso Negado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  // ── Painel Admin ───────────────────────────────────────────
  Widget _buildPanel() {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────
          Container(
            width: 200,
            color: AppTheme.cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  color: AppTheme.primaryRed,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text('ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                      Text('Matrix Race', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),

                // Botões de ação
                InkWell(
                  onTap: _logout,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Sair', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                Divider(color: Colors.grey.shade800, height: 1),
                const SizedBox(height: 8),

                // Itens de navegação
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: _sections.map((s) {
                      final isActive = _currentSection == s['key'];
                      return InkWell(
                        onTap: () => setState(() => _currentSection = s['key'] as String),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryRed.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive ? Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4)) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(s['icon'] as IconData, size: 18, color: isActive ? AppTheme.primaryRed : Colors.grey),
                              const SizedBox(width: 10),
                              Text(
                                s['label'] as String,
                                style: TextStyle(
                                  color: isActive ? AppTheme.primaryRed : Colors.grey.shade300,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Conteúdo principal ──────────────────────────────
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
}
