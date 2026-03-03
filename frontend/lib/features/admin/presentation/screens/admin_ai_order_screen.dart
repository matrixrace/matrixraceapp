import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela admin para definir a ordem de palpite por IA por corrida
class AdminAiOrderScreen extends StatefulWidget {
  const AdminAiOrderScreen({super.key});

  @override
  State<AdminAiOrderScreen> createState() => _AdminAiOrderScreenState();
}

class _AdminAiOrderScreenState extends State<AdminAiOrderScreen> {
  final ApiClient _api = ApiClient();

  List<dynamic> _races = [];
  dynamic _selectedRace;
  List<dynamic> _orderedDrivers = [];
  bool _loadingRaces = true;
  bool _loadingDrivers = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRaces();
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/races/all');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _races = (res.data as List).reversed.toList();
        _loadingRaces = false;
      });
    } else if (mounted) {
      setState(() => _loadingRaces = false);
    }
  }

  Future<void> _selectRace(dynamic race) async {
    setState(() {
      _selectedRace = race;
      _loadingDrivers = true;
    });

    final raceId = race['id'].toString();
    final results = await Future.wait([
      _api.get('/races/drivers'),
      _api.get('/races/$raceId/ai-order'),
    ]);

    if (!mounted) return;

    final driversRes = results[0];
    final aiOrderRes = results[1];

    List<dynamic> drivers = [];
    if (driversRes.success && driversRes.data != null) {
      drivers = List.from(driversRes.data as List);
    }

    // Se já tem ordem salva, reordena conforme ela
    if (aiOrderRes.success && aiOrderRes.data != null) {
      final saved = aiOrderRes.data as List;
      if (saved.isNotEmpty) {
        final orderedIds = saved
            .map((e) => e['driver_id'] as int)
            .toList();
        final reordered = <dynamic>[];
        for (final id in orderedIds) {
          final d = drivers.firstWhere(
            (x) => x['id'] == id,
            orElse: () => null,
          );
          if (d != null) reordered.add(d);
        }
        for (final d in drivers) {
          if (!reordered.any((r) => r['id'] == d['id'])) reordered.add(d);
        }
        drivers = reordered;
      }
    }

    setState(() {
      _orderedDrivers = drivers;
      _loadingDrivers = false;
    });
  }

  Future<void> _save() async {
    if (_selectedRace == null) return;
    setState(() => _saving = true);

    final order = _orderedDrivers
        .asMap()
        .entries
        .map((e) => {'driverId': e.value['id'], 'position': e.key + 1})
        .toList();

    final raceId = _selectedRace['id'].toString();
    final res = await _api.put('/admin/races/$raceId/ai-order',
        body: {'order': order});

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Ordem salva com sucesso!' : res.message),
          backgroundColor: res.success ? AppTheme.successGreen : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Palpite IA',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Defina a ordem de palpite por IA para cada corrida',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          // Seletor de corrida
          if (_loadingRaces)
            const CircularProgressIndicator()
          else
            DropdownButtonFormField<dynamic>(
              initialValue: _selectedRace,
              decoration: const InputDecoration(
                labelText: 'Selecionar corrida',
                prefixIcon: Icon(Icons.flag),
              ),
              items: _races.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text('R${r['round']} — ${r['name']}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _selectRace(value);
              },
            ),

          const SizedBox(height: 20),

          if (_selectedRace != null) ...[
            if (_loadingDrivers)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Arraste para reordenar os pilotos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_saving ? 'Salvando...' : 'Salvar Ordem IA'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _orderedDrivers.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _orderedDrivers.removeAt(oldIndex);
                      _orderedDrivers.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final driver = _orderedDrivers[index];
                    final photoUrl = driver['photo_url'] as String?;
                    final name = '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim();
                    return ListTile(
                      key: ValueKey(driver['id']),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${index + 1}º',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: index < 3
                                    ? AppTheme.accentGold
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.surfaceColor,
                            backgroundImage: photoUrl != null &&
                                    photoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(photoUrl)
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 18)
                                : null,
                          ),
                        ],
                      ),
                      title: Text(name),
                      subtitle: Text(
                        driver['team_name'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.drag_handle,
                          color: AppTheme.textSecondary),
                    );
                  },
                ),
              ),
            ],
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Selecione uma corrida para definir a ordem IA',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
