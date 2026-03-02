import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de perfil de outro usuário (somente leitura)
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.get('/users/${widget.userId}');
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) {
          _profile = res.data as Map<String, dynamic>;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_profile?['displayName'] ?? 'Perfil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Usuário não encontrado'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final profile = _profile!;
    final avatarUrl = profile['avatarUrl'] as String?;
    final name = profile['displayName'] as String? ?? '?';
    final bio = profile['bio'] as String?;
    final stats = profile['stats'] as Map<String, dynamic>?;
    final leagues = profile['leagues'] as List?;
    final isFriend = profile['isFriend'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.surfaceColor,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // Nome
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          if (!isFriend)
            const Text(
              'Adicione como amigo para ver mais detalhes',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),

          // Bio (apenas para amigos)
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(bio, style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          ],

          // Stats (apenas para amigos)
          if (stats != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Pontos Totais',
                    value: '${stats['totalPoints'] ?? 0}',
                    icon: Icons.star,
                    color: AppTheme.accentGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Ligas',
                    value: '${stats['totalLeagues'] ?? 0}',
                    icon: Icons.groups,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ],
            ),
          ],

          // Ligas (apenas para amigos)
          if (leagues != null && leagues.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ligas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...leagues.map((l) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    l['isPublic'] == true ? Icons.lock_open : Icons.lock_outline,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  title: Text(l['leagueName'] ?? ''),
                )),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
