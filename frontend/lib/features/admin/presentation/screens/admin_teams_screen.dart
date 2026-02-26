import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela Admin — Gerenciar Equipes
class AdminTeamsScreen extends StatefulWidget {
  const AdminTeamsScreen({super.key});

  @override
  State<AdminTeamsScreen> createState() => _AdminTeamsScreenState();
}

class _AdminTeamsScreenState extends State<AdminTeamsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/admin/teams');
    if (mounted) {
      setState(() {
        _teams = (res.data as List?) ?? [];
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
                          Text('Equipes', style: Theme.of(context).textTheme.headlineMedium),
                          Text('${_teams.length} equipes cadastradas',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _teams.map((t) => _buildTeamCard(t)).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildTeamCard(dynamic team) {
    Color teamColor = Colors.grey;
    try {
      final hex = (team['color'] ?? '#888888').replaceAll('#', '');
      if (hex.length == 6) {
        teamColor = Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: teamColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(team['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Cor: ${team['color'] ?? 'N/A'}  •  ${team['driver_count'] ?? 0} pilotos',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _showEditModal(team),
          tooltip: 'Editar',
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic team) async {
    final nameCtrl = TextEditingController(text: team['name'] ?? '');
    final colorCtrl = TextEditingController(text: team['color'] ?? '#000000');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('Editar: ${team['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome da Equipe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: colorCtrl,
              decoration: const InputDecoration(
                labelText: 'Cor (hex, ex: #E8002D)',
                hintText: '#RRGGBB',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.put('/admin/teams/${team['id']}', body: {
                'name': nameCtrl.text,
                'color': colorCtrl.text,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.success ? 'Equipe atualizada!' : 'Erro: ${res.message}'),
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
