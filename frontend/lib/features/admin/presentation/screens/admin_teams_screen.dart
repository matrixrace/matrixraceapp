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
  List<dynamic> _allDrivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.get('/admin/teams'),
      _api.get('/admin/drivers'),
    ]);
    if (mounted) {
      setState(() {
        _teams = (results[0].data as List?) ?? [];
        _allDrivers = (results[1].data as List?) ?? [];
        _loading = false;
      });
    }
  }

  Color _parseColor(dynamic team) {
    try {
      final hex = (team['color'] ?? '#888888').replaceAll('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    return Colors.grey;
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
    final drivers = (team['team_drivers'] as List?) ?? [];
    final color = _parseColor(team);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(team['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${team['color'] ?? 'N/A'}  •  ${drivers.length} piloto${drivers.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Editar equipe',
              onPressed: () => _showEditModal(team),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                ...drivers.map<Widget>((d) => _buildDriverRow(team, d)),
                if (drivers.length < 2) _buildEmptySlot(team),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow(dynamic team, dynamic driver) {
    final photo = driver['photo_url'] as String?;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.surfaceColor,
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null
            ? Text(
                '${driver['number'] ?? '?'}',
                style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              )
            : null,
      ),
      title: Text(
        '${driver['first_name']} ${driver['last_name']}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Nº ${driver['number'] ?? '?'}',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.swap_horiz, size: 22, color: AppTheme.primaryRed),
        tooltip: 'Trocar piloto',
        onPressed: () => _showSwapModal(team: team, currentDriver: driver),
      ),
    );
  }

  Widget _buildEmptySlot(dynamic team) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.surfaceColor,
        child: Icon(Icons.person_add_outlined, size: 16, color: Colors.white38),
      ),
      title: const Text(
        'Vaga disponível',
        style: TextStyle(
            fontSize: 13, color: Colors.white38, fontStyle: FontStyle.italic),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add, size: 22),
        tooltip: 'Adicionar piloto',
        onPressed: () => _showSwapModal(team: team, currentDriver: null),
      ),
    );
  }

  Future<void> _showSwapModal({
    required dynamic team,
    required dynamic currentDriver,
  }) async {
    String search = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Exclude drivers already in this team
          final inTeam = ((team['team_drivers'] as List?) ?? [])
              .map<dynamic>((d) => d['id'])
              .toSet();

          final filtered = _allDrivers.where((d) {
            if (inTeam.contains(d['id'])) return false;
            if (search.isEmpty) return true;
            final name =
                '${d['first_name']} ${d['last_name']}'.toLowerCase();
            return name.contains(search.toLowerCase());
          }).toList();

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: Text(
              currentDriver != null
                  ? 'Substituir ${currentDriver['first_name']} ${currentDriver['last_name']}'
                  : 'Adicionar piloto — ${team['name']}',
            ),
            content: SizedBox(
              width: 360,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setDlg(() => search = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar piloto...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Nenhum piloto disponível',
                                style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              final photo = d['photo_url'] as String?;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.surfaceColor,
                                  backgroundImage: photo != null
                                      ? NetworkImage(photo)
                                      : null,
                                  child: photo == null
                                      ? Text(
                                          '${d['number'] ?? '?'}',
                                          style: const TextStyle(
                                              color: AppTheme.primaryRed,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  '${d['first_name']} ${d['last_name']}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  d['team_name'] ?? 'Sem equipe',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _onDriverSelected(team, currentDriver, d);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onDriverSelected(
    dynamic team,
    dynamic currentDriver,
    dynamic newDriver,
  ) async {
    final newDriverTeamId = newDriver['team_id'];

    // Find source team (if the new driver already belongs to a team)
    dynamic sourceTeam;
    if (newDriverTeamId != null) {
      for (final t in _teams) {
        if (t['id'] == newDriverTeamId) {
          sourceTeam = t;
          break;
        }
      }
    }

    final sourceCount = sourceTeam != null
        ? ((sourceTeam['team_drivers'] as List?) ?? []).length
        : 0;

    if (sourceTeam != null && sourceCount >= 2) {
      // Source team will be left with only 1 driver — show warning
      final sourceTeamName =
          (sourceTeam['name'] as String?) ?? 'equipe de origem';

      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Atenção'),
          content: Text(
              'A equipe "$sourceTeamName" ficará com apenas 1 piloto.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'approve'),
              child: const Text('Aprovar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'approve_and_go'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningOrange),
              child: Text('Aprovar e ir para $sourceTeamName'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;

      final ok = await _applyDriverSwap(team, currentDriver, newDriver);
      if (!ok) return;

      await _load();

      if (choice == 'approve_and_go' && mounted) {
        final sourceTeamId = sourceTeam['id'];
        dynamic updatedSource;
        for (final t in _teams) {
          if (t['id'] == sourceTeamId) {
            updatedSource = t;
            break;
          }
        }
        if (updatedSource != null) {
          _showSwapModal(team: updatedSource, currentDriver: null);
        }
      }
      return;
    }

    // Simple case — no warning needed
    final ok = await _applyDriverSwap(team, currentDriver, newDriver);
    if (ok) await _load();
  }

  /// Assigns [newDriver] to [team] and removes [currentDriver] from the team.
  /// Returns true on success.
  Future<bool> _applyDriverSwap(
    dynamic team,
    dynamic currentDriver,
    dynamic newDriver,
  ) async {
    final res = await _api.put('/admin/drivers/${newDriver['id']}', body: {
      'teamId': team['id'],
    });

    if (!res.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: ${res.message}'),
          backgroundColor: AppTheme.primaryRed,
        ));
      }
      return false;
    }

    // Remove the replaced driver from the team
    if (currentDriver != null) {
      await _api.put('/admin/drivers/${currentDriver['id']}',
          body: {'teamId': null});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Piloto atualizado!'),
        backgroundColor: AppTheme.successGreen,
      ));
    }
    return true;
  }

  Future<void> _showEditModal(dynamic team) async {
    final nameCtrl = TextEditingController(text: team['name'] ?? '');
    final colorCtrl =
        TextEditingController(text: team['color'] ?? '#000000');

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
              decoration:
                  const InputDecoration(labelText: 'Nome da Equipe'),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.put('/admin/teams/${team['id']}',
                  body: {
                    'name': nameCtrl.text,
                    'color': colorCtrl.text,
                  });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.success
                      ? 'Equipe atualizada!'
                      : 'Erro: ${res.message}'),
                  backgroundColor:
                      res.success ? AppTheme.successGreen : AppTheme.primaryRed,
                ));
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
