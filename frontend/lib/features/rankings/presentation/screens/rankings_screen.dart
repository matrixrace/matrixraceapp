import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de Ranking Global
/// Lista os usuários com mais pontos em todas as ligas
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _ranking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.get('/rankings/global');
    if (mounted) {
      setState(() {
        _ranking = res.success && res.data != null ? (res.data as List) : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ranking.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.leaderboard_outlined,
                          size: 64, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text('Nenhuma pontuação ainda.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _ranking.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, i) {
                    final entry = _ranking[i] as Map<String, dynamic>;
                    final position = i + 1;
                    final name = entry['display_name'] ??
                        entry['displayName'] ??
                        'Usuário';
                    final avatar =
                        entry['avatar_url'] ?? entry['avatarUrl'];
                    final points = int.tryParse(
                            entry['total_points']?.toString() ?? '0') ??
                        0;
                    final races = int.tryParse(
                            entry['races_played']?.toString() ?? '0') ??
                        0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: _positionWidget(position),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.surfaceColor,
                            backgroundImage: avatar != null
                                ? NetworkImage(avatar.toString())
                                : null,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppTheme.primaryRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                  '$races ${races == 1 ? 'corrida' : 'corridas'}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
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
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _positionWidget(int position) {
    if (position == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 22));
    }
    if (position == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 22));
    }
    if (position == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 22));
    }
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
