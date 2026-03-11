import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/podium_badges.dart';

/// Aba Placar da área da liga
/// Exibe ranking completo com medalhas, destacando o usuário atual
class PlacarTab extends StatefulWidget {
  final String leagueId;
  final String myUserId;

  const PlacarTab({
    super.key,
    required this.leagueId,
    required this.myUserId,
  });

  @override
  State<PlacarTab> createState() => _PlacarTabState();
}

class _PlacarTabState extends State<PlacarTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  List<dynamic> _ranking = [];
  bool _isLoading = true;
  Map<String, dynamic>? _liveScoring;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.get('/rankings/league/${widget.leagueId}');
    if (mounted) {
      setState(() {
        _ranking = res.success && res.data != null ? (res.data as List) : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ranking.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined,
                size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Nenhuma pontuação ainda.',
                style: TextStyle(color: AppTheme.textSecondary)),
            SizedBox(height: 4),
            Text('Seja o primeiro a fazer um palpite!',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Em caso de empate, quem entrou primeiro na liga fica acima.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _ranking.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, i) {
          final entry = _ranking[i] as Map<String, dynamic>;
          final position = entry['position'] as int? ?? i + 1;
          final userId = entry['userId'] ?? entry['user_id'];
          final name = entry['displayName'] ?? entry['display_name'] ?? '';
          final avatar = entry['avatarUrl'] ?? entry['avatar_url'];
          final points =
              int.tryParse(entry['totalPoints']?.toString() ?? '0') ?? 0;
          final joinedAt = entry['joinedAt']?.toString();
          final isMe = userId.toString() == widget.myUserId;

          return InkWell(
            onTap: () => context.push('/users/$userId'),
            child: Container(
            color: isMe
                ? AppTheme.primaryRed.withValues(alpha: 0.06)
                : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Posição / medalha
                SizedBox(
                  width: 32,
                  child: _positionWidget(position),
                ),
                const SizedBox(width: 12),
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.surfaceColor,
                  backgroundImage:
                      avatar != null ? NetworkImage(avatar.toString()) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Nome + corridas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name.toString(),
                              style: TextStyle(
                                fontWeight: isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PodiumBadges.fromMap(
                            entry['podiumStats'] as Map<String, dynamic>?,
                            fontSize: 11,
                          ),
                        ],
                      ),
                      Text(
                        _formatJoinedAt(joinedAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Pontos
                Text(
                  '$points',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: position <= 3
                        ? _medalColor(position)
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('pts',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionalBadge(String usrId, int officialPts) {
    final ranking = (_liveScoring?['ranking'] as List?) ?? [];
    int provPts = 0;
    for (final r in ranking) {
      if (r['userId']?.toString() == usrId) {
        provPts = r['provisionalPoints'] as int? ?? 0;
        break;
      }
    }
    final total = officialPts + provPts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
        if (provPts > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('+$provPts prov.', style: const TextStyle(fontSize: 9, color: Colors.orange)),
          ),
      ],
    );
  }

  String _formatJoinedAt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return 'Entrou em ${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _positionWidget(int position) {
    if (position == 1) return const Text('🥇', style: TextStyle(fontSize: 22));
    if (position == 2) return const Text('🥈', style: TextStyle(fontSize: 22));
    if (position == 3) return const Text('🥉', style: TextStyle(fontSize: 22));
    return Text(
      '$position',
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary),
      textAlign: TextAlign.center,
    );
  }

  Color _medalColor(int position) {
    if (position == 1) return const Color(0xFFFFD700);
    if (position == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }
}
