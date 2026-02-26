import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(displayName, style: Theme.of(context).textTheme.titleLarge),
            if (email != null) ...[
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(bio, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            ],
            if (city != null || state != null || country != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
        Expanded(
          child: _ActionCard(
            icon: Icons.people_outline,
            label: 'Amigos',
            onTap: () => context.push('/friends'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.chat_bubble_outline,
            label: 'Mensagens',
            onTap: () => context.push('/messages'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.notifications_outlined,
            label: 'Notificações',
            onTap: () => context.push('/notifications'),
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.primaryRed, size: 26),
              const SizedBox(height: 6),
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
        Text('Minhas Ligas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_activeLeagues.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Você ainda não participa de nenhuma liga.', style: TextStyle(color: AppTheme.textSecondary)),
              ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceColor,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
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
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => context.push('/leagues/${league['id']}'),
      ),
    );
  }
}
