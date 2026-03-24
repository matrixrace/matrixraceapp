import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/pending_redirect_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Tela de entrada numa liga via link compartilhado (/join/:code).
///
/// - Usuário autenticado → entra automaticamente na liga.
/// - Usuário não autenticado → mostra info da liga + botões de login/registro.
class JoinLeagueScreen extends StatefulWidget {
  final String code;
  const JoinLeagueScreen({super.key, required this.code});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _league;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeagueInfo();
  }

  Future<void> _loadLeagueInfo() async {
    final res = await _api.get('/leagues/public-info/${widget.code}');
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _league = res.data as Map<String, dynamic>;
        _isLoading = false;
      });
      _tryAutoJoin();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.statusCode == 404
            ? 'Código de convite inválido'
            : 'Erro ao carregar informações da liga';
      });
    }
  }

  void _tryAutoJoin() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _joinLeague();
    }
  }

  Future<void> _joinLeague() async {
    setState(() => _isJoining = true);

    final res = await _api.post('/leagues/join-by-code', body: {'code': widget.code});
    if (!mounted) return;

    if (res.success) {
      final leagueData = res.data as Map<String, dynamic>?;
      final leagueId = leagueData?['league']?['id'] ?? _league?['id'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.green),
      );

      if (leagueId != null) {
        context.go('/leagues/$leagueId');
      } else {
        context.go('/leagues');
      }
    } else {
      setState(() => _isJoining = false);

      // Já é membro — redireciona direto para a liga
      if (res.statusCode == 409) {
        final leagueId = _league?['id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já é membro desta liga')),
        );
        if (leagueId != null) {
          context.go('/leagues/$leagueId');
        } else {
          context.go('/leagues');
        }
        return;
      }

      // Limite de ligas atingido
      final msg = res.message.toLowerCase();
      if (msg.contains('limite')) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(child: Text('Limite de ligas atingido')),
              ],
            ),
            content: const Text(
              'Você atingiu o limite de ligas simultâneas e não foi possível entrar nesta liga.\n\n'
              'Quando as corridas de uma liga que você participa forem finalizadas, ela será desativada e você poderá entrar em novas ligas.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      } else {
        setState(() => _errorMessage = res.message);
      }
    }
  }

  void _goToLogin() {
    PendingRedirectService.save('/join/${widget.code}');
    context.go('/login');
  }

  void _goToRegister() {
    PendingRedirectService.save('/join/${widget.code}');
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Caso o usuário retorne da tela de login sem reload
          if (state is AuthAuthenticated && _league != null && !_isJoining) {
            _joinLeague();
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          SizedBox(height: 16),
          Text('Carregando...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      );
    }

    if (_errorMessage != null && _league == null) {
      return _buildErrorView();
    }

    if (_isJoining) {
      return Column(
        children: [
          _buildLeagueCard(),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          const Text('Entrando na liga...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      );
    }

    // Liga carregada, usuário não autenticado
    return Column(
      children: [
        _buildLeagueCard(),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildAuthPrompt(),
      ],
    );
  }

  Widget _buildLeagueCard() {
    final league = _league;
    if (league == null) return const SizedBox.shrink();

    final name = league['name'] as String? ?? 'Liga';
    final description = league['description'] as String?;
    final ownerName = league['owner_name'] as String? ?? '';
    final memberCount = league['member_count'] ?? 0;
    final isPublic = league['is_public'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        children: [
          // Ícone
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPublic ? Icons.groups_outlined : Icons.lock_outline,
              size: 32,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),

          // Texto "Você foi convidado para"
          const Text(
            'Você foi convidado para',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Nome da liga
          Text(
            name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderSubtle),
          const SizedBox(height: 12),

          // Info: membros + criador
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$memberCount membros',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              if (ownerName.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ownerName,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Para entrar na liga, faça login ou crie uma conta',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Botão: Entrar com sua conta
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _goToLogin,
            icon: const Icon(Icons.login),
            label: const Text('Entrar com sua conta'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botão: Criar conta
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _goToRegister,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Criar conta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.borderMedium),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.link_off, size: 40, color: Colors.red),
        ),
        const SizedBox(height: 20),
        Text(
          _errorMessage!,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'O link pode estar expirado ou o código é inválido.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Voltar ao Início'),
        ),
      ],
    );
  }
}
