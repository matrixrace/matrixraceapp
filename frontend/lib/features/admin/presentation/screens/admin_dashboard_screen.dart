import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.get('/admin/dashboard');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _stats = res.data['stats'] as Map<String, dynamic>?;
        _nextRaces = (res.data['nextRaces'] as List?) ?? [];
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
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
    final cards = [
      _StatCard(label: 'Usuários', value: _stats?['total_users'] ?? 0, icon: Icons.people, color: Colors.blue),
      _StatCard(label: 'Corridas', value: _stats?['total_races'] ?? 0, icon: Icons.flag, color: AppTheme.primaryRed),
      _StatCard(label: 'Concluídas', value: _stats?['completed_races'] ?? 0, icon: Icons.check_circle, color: AppTheme.successGreen),
      _StatCard(label: 'Ligas', value: _stats?['total_leagues'] ?? 0, icon: Icons.groups, color: AppTheme.accentGold),
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
          children: cards.map((c) => _buildStatCard(c)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatCard c) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(c.icon, color: c.color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.value}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: c.color,
                ),
              ),
              Text(c.label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextRaces() {
    if (_nextRaces.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhuma corrida futura encontrada.'),
        ),
      );
    }
    return Column(
      children: _nextRaces.map((r) {
        final raceDate = DateTime.tryParse(r['race_date'] ?? '');
        final dateStr = raceDate != null
            ? '${raceDate.day.toString().padLeft(2, '0')}/${raceDate.month.toString().padLeft(2, '0')}/${raceDate.year}'
            : 'Data N/A';
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
                color: (r['is_completed'] == true ? AppTheme.successGreen : AppTheme.warningOrange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r['is_completed'] == true ? 'Concluída' : 'Ativa',
                style: TextStyle(
                  color: r['is_completed'] == true ? AppTheme.successGreen : AppTheme.warningOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
}
