import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';

class AdminLiveResultsScreen extends StatefulWidget {
  const AdminLiveResultsScreen({super.key});

  @override
  State<AdminLiveResultsScreen> createState() => _AdminLiveResultsScreenState();
}

class _AdminLiveResultsScreenState extends State<AdminLiveResultsScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();

  // Corridas
  List<Map<String, dynamic>> _races = [];
  int? _selectedRaceId;
  bool _loadingRaces = true;

  // Sessoes
  Map<String, dynamic>? _raceInfo;
  List<String> _availableSessions = [];
  Map<String, dynamic> _sessions = {};
  TabController? _tabController;
  bool _loadingSessions = false;
  bool _refreshing = false;

  // Pilotos para fallback manual
  List<Map<String, dynamic>> _drivers = [];

  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadRaces();
    _loadDrivers();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/admin/races');
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _races = (res.data as List).map((r) => Map<String, dynamic>.from(r)).toList();
        _loadingRaces = false;
      });
    }
  }

  Future<void> _loadDrivers() async {
    final res = await _api.get('/admin/drivers');
    if (!mounted) return;
    if (res.success && res.data != null) {
      _drivers = (res.data as List).map((d) => Map<String, dynamic>.from(d)).toList();
    }
  }

  Future<void> _selectRace(int raceId) async {
    setState(() { _selectedRaceId = raceId; _loadingSessions = true; });

    // Socket
    _socketSub?.cancel();
    _socket.joinRace(raceId);
    _socketSub = _socket.sessionResultsStream.listen((data) {
      if (data['raceId'] == _selectedRaceId) _loadSessionData();
    });

    await _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    if (_selectedRaceId == null) return;

    final res = await _api.get('/live/races/$_selectedRaceId/sessions');
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final available = (data['availableSessions'] as List?)?.cast<String>() ?? [];

      setState(() {
        _raceInfo = data['race'] as Map<String, dynamic>?;
        _availableSessions = available;
        _sessions = data['sessions'] as Map<String, dynamic>? ?? {};
        _loadingSessions = false;

        if (_tabController == null || _tabController!.length != available.length) {
          _tabController?.dispose();
          _tabController = TabController(length: available.length, vsync: this);
        }
      });
    }
  }

  Future<void> _refreshSession(String sessionType) async {
    if (_selectedRaceId == null) return;
    setState(() => _refreshing = true);

    final res = await _api.post('/live/admin/races/$_selectedRaceId/sessions/$sessionType/refresh');
    if (!mounted) return;

    setState(() => _refreshing = false);

    if (res.success) {
      _showSnack('Sessao ${_sessionLabel(sessionType)} atualizada!', Colors.green);
      await _loadSessionData();
    } else {
      final isManualFallback = res.data is Map && res.data['manualFallback'] == true;
      if (isManualFallback) {
        _showSnack('OpenF1 indisponivel. Use o modo manual.', Colors.orange);
      } else {
        _showSnack(res.message ?? 'Erro ao atualizar', Colors.red);
      }
    }
  }

  Future<void> _finalizeResults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Enviar para Pontuacao'),
        content: const Text('Isso vai copiar os resultados da corrida como oficiais e calcular a pontuacao de todos os usuarios. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedRaceId == null) return;

    final res = await _api.post('/live/admin/races/$_selectedRaceId/finalize-results');
    if (!mounted) return;

    if (res.success) {
      _showSnack('Pontuacoes calculadas com sucesso!', Colors.green);
      _loadSessionData();
    } else {
      _showSnack(res.message ?? 'Erro ao finalizar', Colors.red);
    }
  }

  Future<void> _openManualMode(String sessionType) async {
    // Ordena pilotos por posicao (ou ordem padrao)
    final currentResults = (_sessions[sessionType]?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    List<Map<String, dynamic>> orderedDrivers;

    if (currentResults.isNotEmpty) {
      orderedDrivers = currentResults.map((r) {
        final driver = _drivers.firstWhere((d) => d['id'] == r['driverId'], orElse: () => r);
        return {
          'driverId': r['driverId'],
          'name': '${driver['firstName'] ?? r['firstName'] ?? ''} ${driver['lastName'] ?? r['lastName'] ?? ''}',
          'abbreviation': driver['abbreviation'] ?? r['abbreviation'] ?? '???',
        };
      }).toList();
    } else {
      orderedDrivers = _drivers.where((d) => d['isActive'] == true).map((d) => {
        'driverId': d['id'],
        'name': '${d['firstName']} ${d['lastName']}',
        'abbreviation': d['abbreviation'] ?? '???',
      }).toList();
    }

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => _ManualOrderDialog(drivers: orderedDrivers, sessionType: sessionType),
    );

    if (result == null || _selectedRaceId == null) return;

    final body = {
      'results': result.asMap().entries.map((e) => {
        'driverId': e.value['driverId'],
        'position': e.key + 1,
      }).toList(),
    };

    final res = await _api.post('/live/admin/races/$_selectedRaceId/sessions/$sessionType/manual', body: body);
    if (!mounted) return;

    if (res.success) {
      _showSnack('Resultados manuais salvos!', Colors.green);
      _loadSessionData();
    } else {
      _showSnack(res.message ?? 'Erro', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  String _sessionLabel(String type) {
    switch (type) {
      case 'FP1': return 'TL1';
      case 'FP2': return 'TL2';
      case 'FP3': return 'TL3';
      case 'qualifying': return 'Classificacao';
      case 'sprint_qualifying': return 'Classif. Sprint';
      case 'sprint': return 'Sprint';
      case 'race': return 'Corrida';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Lista de corridas (lateral)
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                child: const Text('Selecione a Corrida', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
              ),
              Expanded(
                child: _loadingRaces
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _races.length,
                      itemBuilder: (ctx, i) {
                        final race = _races[i];
                        final isSelected = race['id'] == _selectedRaceId;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryRed.withValues(alpha: 0.1),
                          title: Text(race['name'] ?? 'Corrida ${race['round']}', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text('R${race['round']} - ${race['season']}', style: const TextStyle(fontSize: 11)),
                          trailing: race['isCompleted'] == true
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
                            : (race['isSprintWeekend'] == true ? const Icon(Icons.bolt, color: Colors.orange, size: 16) : null),
                          onTap: () => _selectRace(race['id'] as int),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Conteudo da sessao
        Expanded(
          child: _selectedRaceId == null
            ? const Center(child: Text('Selecione uma corrida', style: TextStyle(color: AppTheme.textSecondary)))
            : _loadingSessions
              ? const Center(child: CircularProgressIndicator())
              : _buildSessionContent(),
        ),
      ],
    );
  }

  Widget _buildSessionContent() {
    if (_availableSessions.isEmpty) {
      return const Center(child: Text('Nenhuma sessao disponivel'));
    }

    return Column(
      children: [
        // Race info header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.cardBackground,
          child: Row(
            children: [
              Text(_raceInfo?['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_raceInfo?['isSprintWeekend'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('SPRINT', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              if (_raceInfo?['isCompleted'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('FINALIZADA', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        // Tabs
        Container(
          color: AppTheme.cardBackground,
          child: TabBar(
            controller: _tabController,
            isScrollable: _availableSessions.length > 4,
            indicatorColor: AppTheme.primaryRed,
            labelColor: AppTheme.primaryRed,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: _availableSessions.map((s) => Tab(text: _sessionLabel(s))).toList(),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _availableSessions.map((s) => _buildAdminSessionTab(s)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminSessionTab(String sessionType) {
    final session = _sessions[sessionType];
    final results = (session?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final updatedAt = session?['updatedAt'];
    final isRace = sessionType == 'race';

    return Column(
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Atualizar da OpenF1
              ElevatedButton.icon(
                onPressed: _refreshing ? null : () => _refreshSession(sessionType),
                icon: _refreshing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_download, size: 18),
                label: Text(_refreshing ? 'Atualizando...' : 'Atualizar da OpenF1'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              const SizedBox(width: 8),
              // Manual
              OutlinedButton.icon(
                onPressed: () => _openManualMode(sessionType),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Manual'),
              ),
              const Spacer(),
              // Timestamp
              if (updatedAt != null)
                Text('Atualizado: ${_formatTime(updatedAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              // Finalizar (so para corrida)
              if (isRace && results.isNotEmpty) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _finalizeResults,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar para Pontuacao'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                ),
              ],
            ],
          ),
        ),
        // Results table
        if (results.isEmpty)
          const Expanded(child: Center(child: Text('Nenhum resultado ainda. Clique em "Atualizar da OpenF1" ou "Manual".',
            style: TextStyle(color: AppTheme.textSecondary))))
        else
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Pos', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Piloto', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Equipe', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tempo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Gap', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Pneu', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Pits', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: results.map((r) {
                    return DataRow(cells: [
                      DataCell(Text('${r['position']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(r['abbreviation'] ?? '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}')),
                      DataCell(Text(r['teamName'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                      DataCell(Text(r['bestLapTime'] ?? '-')),
                      DataCell(Text(r['gap'] ?? '-')),
                      DataCell(Text(r['tireCompound'] ?? '-')),
                      DataCell(Text('${r['pitStops'] ?? 0}')),
                      DataCell(Text(r['status'] ?? 'OK', style: TextStyle(color: r['status'] != null ? Colors.red : Colors.green))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// Dialog para ordenar pilotos manualmente (drag and drop)
class _ManualOrderDialog extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;
  final String sessionType;

  const _ManualOrderDialog({required this.drivers, required this.sessionType});

  @override
  State<_ManualOrderDialog> createState() => _ManualOrderDialogState();
}

class _ManualOrderDialogState extends State<_ManualOrderDialog> {
  late List<Map<String, dynamic>> _orderedDrivers;

  @override
  void initState() {
    super.initState();
    _orderedDrivers = List.from(widget.drivers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBackground,
      title: Text('Ordenar Pilotos - ${widget.sessionType}'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: ReorderableListView.builder(
          itemCount: _orderedDrivers.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = _orderedDrivers.removeAt(oldIndex);
              _orderedDrivers.insert(newIndex, item);
            });
          },
          itemBuilder: (ctx, i) {
            final d = _orderedDrivers[i];
            return ListTile(
              key: ValueKey(d['driverId']),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.2),
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              title: Text('${d['abbreviation']} - ${d['name']}', style: const TextStyle(fontSize: 13)),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _orderedDrivers),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
