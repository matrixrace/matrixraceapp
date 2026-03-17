import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/podium_badges.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Tela de Perfil Pessoal
/// Mostra foto, nome, bio, ligas e atalhos para amigos e chat
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final res = await _api.get('/auth/me');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _profileData = res.data as Map<String, dynamic>;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TutorialBloc>().add(TutorialScreenVisited('profile'));
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 20),
                _buildActionsRow(),
                const SizedBox(height: 24),
                _buildLeaguesSection(),
              ],
            ),
          );
  }

  Widget _buildProfileHeader() {
    final displayName = _profileData?['displayName'] ?? 'Usuário';
    final avatarUrl = _profileData?['avatarUrl'] as String?;
    final bio = _profileData?['bio'] as String?;
    final email = _profileData?['email'] as String?;
    final city = _profileData?['city'] as String?;
    final state = _profileData?['state'] as String?;
    final country = _profileData?['country'] as String?;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            AppTheme.cardBackground,
            AppTheme.cardBackground,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.35, 1.0],
        ),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar com glow
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.surfaceColor,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: GoogleFonts.exo2(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayName, style: AppTheme.displayStyle(fontSize: 20)),
                PodiumBadges.fromMap(
                  _profileData?['podiumStats'] as Map<String, dynamic>?,
                  fontSize: 14,
                ),
              ],
            ),
            if (email != null) ...[
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(bio, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4), textAlign: TextAlign.center),
            ],
            if (city != null || state != null || country != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [
                        if (city != null && city.isNotEmpty) city,
                        if (state != null && state.isNotEmpty) state,
                        if (country != null && country.isNotEmpty) country,
                      ].join(', '),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: TutorialKeys.profileEdit,
              onPressed: () => context.push('/profile/edit').then((_) => _loadProfile()),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar Perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(child: _ActionCard(
          icon: Icons.people_outline,
          label: 'Amigos',
          onTap: () => context.push('/friends'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionCard(
          icon: Icons.chat_bubble_outline,
          label: 'Mensagens',
          onTap: () => context.push('/messaging'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionCard(
          icon: Icons.notifications_outlined,
          label: 'Notificações',
          onTap: () => context.push('/notifications'),
        )),
      ],
    );
  }

  Widget _buildLeaguesSection() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return _LeaguesSectionLoader(api: _api);
      },
    );
  }
}

// ── Card de ação (Amigos / Mensagens / Notificações) ────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Seção de ligas do usuário ────────────────────────────────────────────────

class _LeaguesSectionLoader extends StatefulWidget {
  final ApiClient api;
  const _LeaguesSectionLoader({required this.api});

  @override
  State<_LeaguesSectionLoader> createState() => _LeaguesSectionLoaderState();
}

class _LeaguesSectionLoaderState extends State<_LeaguesSectionLoader> {
  List<dynamic> _activeLeagues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    final res = await widget.api.get('/leagues');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _activeLeagues = res.data as List;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Minhas Ligas', style: AppTheme.displayStyle(fontSize: 18)),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_activeLeagues.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                Icon(Icons.groups_outlined, size: 40, color: AppTheme.textSecondary),
                const SizedBox(height: 8),
                const Text('Você ainda não participa de nenhuma liga.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          ..._activeLeagues.map((league) => _LeagueItem(league: league)),
      ],
    );
  }
}

class _LeagueItem extends StatelessWidget {
  final dynamic league;
  const _LeagueItem({required this.league});

  @override
  Widget build(BuildContext context) {
    final name = league['name'] ?? '';
    final isPublic = league['isPublic'] ?? league['is_public'] ?? false;
    final raceCount = int.tryParse(league['race_count']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.exo2(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Row(
            children: [
              Text(isPublic ? 'Pública' : 'Privada',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.flag_outlined, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 3),
              Text('$raceCount GPs',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          onTap: () => context.push('/leagues/${league['id']}'),
        ),
      ),
    );
  }
}
