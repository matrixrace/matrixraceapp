import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de perfil público de outro usuário.
/// Mostra status de amizade e permite solicitar/aceitar/cancelar amizade.
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
  bool _actionLoading = false;
  late bool _isOwnProfile;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = FirebaseAuth.instance.currentUser?.uid == widget.userId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final res = await _api.get('/users/${widget.userId}');
    if (mounted) {
      setState(() {
        _profile = res.success && res.data != null
            ? res.data as Map<String, dynamic>
            : null;
        _isLoading = false;
      });
    }
  }

  // ── Ações de amizade ──────────────────────────────────────────────────────

  Future<void> _sendRequest() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actionLoading = true);
    final res = await _api.post('/friends/request/${widget.userId}');
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res.success) {
        await _load();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRequest() async {
    final friendshipId = _profile?['friendshipId'];
    if (friendshipId == null) return;
    setState(() => _actionLoading = true);
    final res = await _api.delete('/friends/$friendshipId');
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res.success) await _load();
    }
  }

  Future<void> _acceptRequest() async {
    final friendshipId = _profile?['friendshipId'];
    if (friendshipId == null) return;
    setState(() => _actionLoading = true);
    final res = await _api.put('/friends/$friendshipId/accept');
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res.success) await _load();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _profile?['displayName'] as String? ?? 'Perfil';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(name),
      ),
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
    final friendshipStatus = profile['friendshipStatus'] as String? ?? 'none';
    final isFriend = friendshipStatus == 'friends';

    final bio = profile['bio'] as String?;
    final stats = profile['stats'] as Map<String, dynamic>?;
    final leagues = profile['leagues'] as List?;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Banner + Avatar ───────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Banner colorido
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryRed.withValues(alpha: 0.7),
                      AppTheme.primaryRed.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
              // Avatar centralizado sobre o banner
              Positioned(
                bottom: -44,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.darkBackground,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.surfaceColor,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryRed),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 56), // espaço para o avatar

          // ── Nome ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // ── Botão de amizade (não mostra para si mesmo) ───────────
                if (!_isOwnProfile) _buildFriendshipButton(friendshipStatus),

                if (!isFriend && !_isOwnProfile) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Icon(Icons.lock_outline,
                      size: 40, color: AppTheme.textSecondary),
                  const SizedBox(height: 8),
                  const Text(
                    'Adicione como amigo para ver o perfil completo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Bio (apenas amigos) ───────────────────────────────────
                if (isFriend && bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(bio,
                        style: const TextStyle(
                            color: AppTheme.textSecondary)),
                  ),
                ],

                // ── Stats (apenas amigos) ─────────────────────────────────
                if (isFriend && stats != null) ...[
                  const SizedBox(height: 16),
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

                // ── Ligas (apenas amigos) ─────────────────────────────────
                if (isFriend && leagues != null && leagues.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ligas',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  ...leagues.map((l) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          l['isPublic'] == true
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        title: Text(l['leagueName'] ?? ''),
                      )),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendshipButton(String status) {
    if (_actionLoading) {
      return const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case 'friends':
        return OutlinedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Amigos'),
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.successGreen,
            side: const BorderSide(color: AppTheme.successGreen),
          ),
        );

      case 'pending_sent':
        return OutlinedButton.icon(
          icon: const Icon(Icons.hourglass_top, size: 16),
          label: const Text('Aguardando... (toque para cancelar)'),
          onPressed: _cancelRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.textSecondary),
          ),
        );

      case 'pending_received':
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Aprovar Amizade'),
          onPressed: _acceptRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
          ),
        );

      default: // 'none'
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Solicitar Amizade'),
          onPressed: _sendRequest,
        );
    }
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
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
