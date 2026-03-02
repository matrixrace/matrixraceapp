import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela admin: lista todas as ligas criadas por usuários
class AdminUserLeaguesScreen extends StatefulWidget {
  const AdminUserLeaguesScreen({super.key});

  @override
  State<AdminUserLeaguesScreen> createState() => _AdminUserLeaguesScreenState();
}

class _AdminUserLeaguesScreenState extends State<AdminUserLeaguesScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.get('/admin/leagues/user-leagues');
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) {
          _leagues = res.data as List;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ligas de Usuários')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leagues.isEmpty
              ? const Center(child: Text('Nenhuma liga de usuário encontrada.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _leagues.length,
                    itemBuilder: (context, index) {
                      final league = _leagues[index];
                      final isPublic = league['is_public'] == true;
                      final memberCount = league['member_count'] ?? 0;
                      final raceCount = league['race_count'] ?? 0;
                      final ownerName = league['owner_name'] ?? '?';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              context.push('/leagues/${league['id']}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Ícone público/privado
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isPublic
                                            ? AppTheme.successGreen
                                            : AppTheme.textSecondary)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPublic
                                        ? Icons.lock_open
                                        : Icons.lock_outline,
                                    size: 18,
                                    color: isPublic
                                        ? AppTheme.successGreen
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Informações
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        league['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dono: $ownerName',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badges
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _Badge(
                                      icon: Icons.people,
                                      label: '$memberCount',
                                      color: AppTheme.primaryRed,
                                    ),
                                    const SizedBox(height: 4),
                                    _Badge(
                                      icon: Icons.flag,
                                      label: '$raceCount GPs',
                                      color: AppTheme.accentGold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
