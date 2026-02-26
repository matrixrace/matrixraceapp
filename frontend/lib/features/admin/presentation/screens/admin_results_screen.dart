import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela Admin — Inserir resultado de corrida e calcular pontuações
class AdminResultsScreen extends StatefulWidget {
  const AdminResultsScreen({super.key});

  @override
  State<AdminResultsScreen> createState() => _AdminResultsScreenState();
}

class _AdminResultsScreenState extends State<AdminResultsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _races = [];
  List<dynamic> _drivers = [];
  dynamic _selectedRace;
  List<dynamic> _orderedDrivers = [];
  bool _loadingRaces = true;
  bool _loadingDrivers = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRaces();
    _loadDrivers();
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/admin/races');
    if (mounted) {
      setState(() {
        _races = (res.data as List?) ?? [];
        _loadingRaces = false;
      });
    }
  }

  Future<void> _loadDrivers() async {
    final res = await _api.get('/admin/drivers');
    if (mounted) {
      setState(() {
        _drivers = ((res.data as List?) ?? [])
            .where((d) => d['is_active'] == true)
            .toList();
        _drivers.sort((a, b) => (a['number'] ?? 0).compareTo(b['number'] ?? 0));
        _loadingDrivers = false;
      });
    }
  }

  void _selectRace(dynamic race) {
    setState(() {
      _selectedRace = race;
      _orderedDrivers = List.from(_drivers);
    });
  }

  Future<void> _saveResult() async {
    if (_selectedRace == null || _orderedDrivers.isEmpty) return;
    setState(() => _saving = true);
    final results = _orderedDrivers.asMap().entries.map((e) {
      return {'driverId': e.value['id'], 'position': e.key + 1};
    }).toList();

    final res = await _api.post('/admin/races/${_selectedRace['id']}/results', body: {'results': results});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Resultado salvo com sucesso!' : 'Erro: ${res.message}'),
          backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _calculateScores() async {
    if (_selectedRace == null) return;
    setState(() => _saving = true);
    final res = await _api.post('/admin/races/${_selectedRace['id']}/calculate-scores', body: {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Pontuações calculadas! ${res.message}' : 'Erro: ${res.message}'),
          backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRaces || _loadingDrivers) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Painel de seleção de corrida
        Container(
          width: 280,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Selecionar Corrida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _races.length,
                  itemBuilder: (ctx, i) {
                    final r = _races[i];
                    final isSelected = _selectedRace?['id'] == r['id'];
                    return InkWell(
                      onTap: () => _selectRace(r),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryRed.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4)) : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${r['round']}.',
                              style: TextStyle(
                                color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r['name'] ?? '',
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryRed : Colors.white,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Painel de resultado
        Expanded(
          child: _selectedRace == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 48, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text('Selecione uma corrida à esquerda', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedRace['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('Arraste para ordenar os pilotos (1º ao último)',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (_saving)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            OutlinedButton.icon(
                              onPressed: _saveResult,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('Salvar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.successGreen,
                                side: const BorderSide(color: AppTheme.successGreen),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _calculateScores,
                              icon: const Icon(Icons.calculate, size: 16),
                              label: const Text('Calcular Pontos'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _orderedDrivers.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _orderedDrivers.removeAt(oldIndex);
                            _orderedDrivers.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (ctx, i) {
                          final d = _orderedDrivers[i];
                          return Card(
                            key: ValueKey(d['id']),
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.primaryRed,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(d['team_name'] ?? '', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
