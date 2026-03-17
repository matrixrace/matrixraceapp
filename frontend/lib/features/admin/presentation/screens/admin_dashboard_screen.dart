import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

/// Dashboard administrativo — estatísticas gerais do sistema
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _nextRaces = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _api.get('/admin/dashboard');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _stats = res.data['stats'] as Map<String, dynamic>?;
        _nextRaces = (res.data['nextRaces'] as List?) ?? [];
        _loading = false;
      });
    } else if (mounted) {
      setState(() {
        _loading = false;
        _hasError = !res.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: ShimmerGrid(crossAxisCount: 2, itemCount: 6, childAspectRatio: 1.6),
      );
    }

    if (_hasError) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Erro ao carregar dashboard',
          subtitle: 'Não foi possível carregar as estatísticas.',
          action: ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tentar novamente'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Visão geral do sistema', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            Text('Próximas Corridas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildNextRaces(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.cardDecoration(),
        child: const EmptyStateWidget(
          icon: Icons.analytics_outlined,
          title: 'Sem estatísticas',
          subtitle: 'Nenhum dado disponível ainda.',
        ),
      );
    }

    final cards = [
      _StatCard(label: 'Usuários', value: _stats?['total_users'] ?? 0, icon: Icons.people, color: Colors.blue),
      _StatCard(label: 'Corridas', value: _stats?['total_races'] ?? 0, icon: Icons.flag, color: AppTheme.primaryRed),
      _StatCard(label: 'Concluídas', value: _stats?['completed_races'] ?? 0, icon: Icons.check_circle, color: AppTheme.successGreen),
      _StatCard(label: 'Ligas', value: _stats?['total_leagues'] ?? 0, icon: Icons.groups, color: AppTheme.accentGold, onTap: () => context.go('/admin/user-leagues')),
      _StatCard(label: 'Ligas Of.', value: _stats?['official_leagues'] ?? 0, icon: Icons.verified, color: Colors.purple),
      _StatCard(label: 'Palpites', value: _stats?['total_predictions'] ?? 0, icon: Icons.edit, color: Colors.teal),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: cards.asMap().entries.map((e) {
            return _buildStatCard(e.value)
                .animate()
                .fadeIn(duration: 300.ms, delay: (e.key * 60).ms)
                .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: (e.key * 60).ms);
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatCard c) {
    final hasValue = c.value != null && c.value != 0;

    return InkWell(
      onTap: c.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.color.withValues(alpha: c.onTap != null ? 0.6 : 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(c.icon, color: c.color, size: 20),
                ),
                if (c.onTap != null)
                  Icon(Icons.chevron_right, color: c.color.withValues(alpha: 0.5), size: 18),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasValue ? '${c.value}' : '—',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? c.color : AppTheme.textSecondary,
                  ),
                ),
                Text(c.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextRaces() {
    if (_nextRaces.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.cardDecoration(),
        child: const EmptyStateWidget(
          icon: Icons.event_busy,
          title: 'Nenhuma corrida futura',
          subtitle: 'Sincronize o calendário para adicionar corridas.',
        ),
      );
    }
    return Column(
      children: _nextRaces.asMap().entries.map((e) {
        final r = e.value;
        final i = e.key;
        final raceDate = DateTime.tryParse(r['race_date'] ?? '');
        final dateStr = raceDate != null
            ? '${raceDate.day.toString().padLeft(2, '0')}/${raceDate.month.toString().padLeft(2, '0')}/${raceDate.year}'
            : 'Data N/A';
        final isCompleted = r['is_completed'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.15),
              child: Text(
                '${r['round']}',
                style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(r['name'] ?? ''),
            subtitle: Text(dateStr),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isCompleted ? AppTheme.successGreen : AppTheme.warningOrange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.schedule,
                    size: 12,
                    color: isCompleted ? AppTheme.successGreen : AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted ? 'Concluída' : 'Ativa',
                    style: TextStyle(
                      color: isCompleted ? AppTheme.successGreen : AppTheme.warningOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms, delay: (i * 50).ms);
      }).toList(),
    );
  }
}

class _StatCard {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});
}
