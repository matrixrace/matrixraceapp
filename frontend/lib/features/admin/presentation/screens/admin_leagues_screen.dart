import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela Admin — Gerenciar Ligas Oficiais
class AdminLeaguesScreen extends StatefulWidget {
  const AdminLeaguesScreen({super.key});

  @override
  State<AdminLeaguesScreen> createState() => _AdminLeaguesScreenState();
}

class _AdminLeaguesScreenState extends State<AdminLeaguesScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _leagues = [];
  bool _loading = true;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _seedLeagues() async {
    setState(() => _seeding = true);
    final res = await _api.post('/admin/leagues/seed');
    if (mounted) {
      setState(() => _seeding = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success ? res.message : 'Erro: ${res.message}'),
        backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
      ));
      if (res.success) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/admin/leagues');
    if (mounted) {
      setState(() {
        _leagues = (res.data as List?) ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ligas Oficiais', style: Theme.of(context).textTheme.headlineMedium),
                          Text('${_leagues.length} ligas oficiais',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    if (_seeding)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _seedLeagues,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Criar Ligas Oficiais'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                      ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _leagues.map((l) => _buildLeagueCard(l)).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildLeagueCard(dynamic league) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
          ),
          child: Text(
            league['invite_code'] ?? '',
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        title: Text(league['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${league['member_count'] ?? 0} membros  •  GP: ${league['race_name'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _showEditModal(league),
          tooltip: 'Editar',
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic league) async {
    final nameCtrl = TextEditingController(text: league['name'] ?? '');
    final descCtrl = TextEditingController(text: league['description'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('Editar: ${league['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome da Liga'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.put('/admin/leagues/${league['id']}', body: {
                'name': nameCtrl.text,
                'description': descCtrl.text,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.success ? 'Liga atualizada!' : 'Erro: ${res.message}'),
                    backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
                  ),
                );
                if (res.success) _load();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
