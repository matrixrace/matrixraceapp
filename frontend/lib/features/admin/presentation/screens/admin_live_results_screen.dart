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

class _AdminLiveResultsScreenState extends State<AdminLiveResultsScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();

  List<Map<String, dynamic>> _races = [];
  int? _selectedRaceId;
  bool _loadingRaces = true;

  Map<String, dynamic>? _raceInfo;
  List<String> _availableSessions = [];
  Map<String, dynamic> _sessions = {};
  TabController? _tabController;
  bool _loadingSessions = false;
  bool _saving = false;

  List<Map<String, dynamic>> _drivers = [];

  // Editing state per session
  final Map<String, List<_DriverEntry>> _editingEntries = {};

  // Auto-refresh state
  bool _autoRefreshActive = false;
  int? _autoRefreshRaceId;
  String? _autoRefreshSessionType;
  String? _autoRefreshLastRefresh;
  int _autoRefreshErrorCount = 0;
  bool _togglingAutoRefresh = false;
  String? _autoRefreshSource; // 'manual' | 'scheduler'
  bool _refreshingAll = false;

  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadRaces();
    _loadDrivers();
    _loadAutoRefreshStatus();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAutoRefreshStatus() async {
    final res = await _api.get('/live/admin/auto-refresh/status');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _autoRefreshActive = data['active'] == true;
        _autoRefreshRaceId = data['raceId'] as int?;
        _autoRefreshSessionType = data['sessionType'] as String?;
        _autoRefreshLastRefresh = data['lastRefresh'] as String?;
        _autoRefreshErrorCount = (data['errorCount'] as int?) ?? 0;
        _autoRefreshSource = data['source'] as String?;
      });
    }
  }

  Future<void> _toggleAutoRefresh(String sessionType) async {
    if (_selectedRaceId == null) return;
    setState(() => _togglingAutoRefresh = true);

    final isCurrentlyActive = _autoRefreshActive &&
        _autoRefreshRaceId == _selectedRaceId &&
        _autoRefreshSessionType == sessionType;

    if (isCurrentlyActive) {
      final res = await _api.post('/live/admin/auto-refresh/stop');
      if (mounted && res.success) {
        _showSnack('Auto-refresh parado', Colors.orange);
      }
    } else {
      final res = await _api.post('/live/admin/auto-refresh/start', body: {
        'raceId': _selectedRaceId,
        'sessionType': sessionType,
        'intervalSeconds': 30,
      });
      if (mounted && res.success) {
        _showSnack('Auto-refresh ativado (30s)', Colors.green);
      } else if (mounted) {
        _showSnack(res.message ?? 'Erro ao ativar', Colors.red);
      }
    }

    await _loadAutoRefreshStatus();
    if (mounted) setState(() => _togglingAutoRefresh = false);
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/admin/races');
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _races = (res.data as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _loadingRaces = false;
      });
    }
  }

  Future<void> _loadDrivers() async {
    final res = await _api.get('/admin/drivers');
    if (!mounted) return;
    if (res.success && res.data != null) {
      _drivers = (res.data as List)
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
    }
  }

  Future<void> _selectRace(int raceId) async {
    setState(() {
      _selectedRaceId = raceId;
      _loadingSessions = true;
      _editingEntries.clear();
    });

    _socketSub?.cancel();
    _socket.joinRace(raceId);
    _socketSub = _socket.sessionResultsStream.listen((data) {
      if (data['raceId'] == _selectedRaceId) {
        _loadSessionData();
        _loadAutoRefreshStatus();
      }
    });

    await _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    if (_selectedRaceId == null) return;

    final res = await _api.get('/live/races/$_selectedRaceId/sessions');
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final available =
          (data['availableSessions'] as List?)?.cast<String>() ?? [];

      setState(() {
        _raceInfo = data['race'] as Map<String, dynamic>?;
        _availableSessions = available;
        _sessions = data['sessions'] as Map<String, dynamic>? ?? {};
        _loadingSessions = false;

        if (_tabController == null ||
            _tabController!.length != available.length) {
          _tabController?.dispose();
          _tabController =
              TabController(length: available.length, vsync: this);
        }

        // Build editing entries from existing data or drivers list
        for (final st in available) {
          if (!_editingEntries.containsKey(st)) {
            _editingEntries[st] = _buildEntries(st);
          }
        }
      });
    }
  }

  List<_DriverEntry> _buildEntries(String sessionType) {
    final session = _sessions[sessionType];
    final results =
        (session?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (results.isNotEmpty) {
      return results.map((r) {
        final driverId = r['driverId'];
        final driver = _drivers.firstWhere(
          (d) => d['id'] == driverId,
          orElse: () => <String, dynamic>{},
        );
        return _DriverEntry(
          driverId: driverId,
          name: r['abbreviation'] ??
              driver['abbreviation'] ??
              '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}',
          fullName:
              '${driver['first_name'] ?? r['firstName'] ?? ''} ${driver['last_name'] ?? r['lastName'] ?? ''}',
          bestLapTime: r['bestLapTime'] ?? r['best_lap_time'] ?? '',
          gap: r['gap'] ?? '',
        );
      }).toList();
    }

    // No existing results — populate from active drivers
    final active =
        _drivers.where((d) => d['is_active'] == true).toList();
    return active.map((d) {
      return _DriverEntry(
        driverId: d['id'],
        name: d['abbreviation'] ?? '???',
        fullName: '${d['first_name']} ${d['last_name']}',
        bestLapTime: '',
        gap: '',
      );
    }).toList();
  }

  Future<void> _saveSession(String sessionType) async {
    if (_selectedRaceId == null) return;
    final entries = _editingEntries[sessionType];
    if (entries == null || entries.isEmpty) return;

    setState(() => _saving = true);

    final body = {
      'results': entries.asMap().entries.map((e) {
        final entry = e.value;
        return {
          'driverId': entry.driverId,
          'position': e.key + 1,
          'bestLapTime': entry.bestLapTime.isNotEmpty ? entry.bestLapTime : null,
          'gap': entry.gap.isNotEmpty ? entry.gap : null,
        };
      }).toList(),
    };

    final res = await _api.post(
      '/live/admin/races/$_selectedRaceId/sessions/$sessionType/manual',
      body: body,
    );
    if (!mounted) return;

    setState(() => _saving = false);

    if (res.success) {
      _showSnack('Sessao ${_sessionLabel(sessionType)} salva!', Colors.green);
      await _loadSessionData();
    } else {
      _showSnack(res.message ?? 'Erro ao salvar', Colors.red);
    }
  }

  Future<void> _finalizeResults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Enviar para Pontuacao'),
        content: const Text(
            'Isso vai copiar os resultados da corrida como oficiais e calcular a pontuacao de todos os usuarios. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedRaceId == null) return;

    final res = await _api
        .post('/live/admin/races/$_selectedRaceId/finalize-results');
    if (!mounted) return;

    if (res.success) {
      _showSnack('Pontuacoes calculadas com sucesso!', Colors.green);
      _loadSessionData();
    } else {
      _showSnack(res.message ?? 'Erro ao finalizar', Colors.red);
    }
  }

  Future<void> _refreshAllSessions() async {
    if (_selectedRaceId == null) return;
    setState(() => _refreshingAll = true);

    final res = await _api
        .post('/live/admin/races/$_selectedRaceId/refresh-all-sessions');
    if (!mounted) return;
    setState(() => _refreshingAll = false);

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final refreshed = (data['refreshed'] as List?) ?? [];
      final failed = (data['failed'] as List?) ?? [];

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: const Text('Resultado do Refresh'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in refreshed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          '${_sessionLabel(r['sessionType'] ?? '')} - ${r['count']} pilotos'),
                    ]),
                  ),
                for (final f in failed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${_sessionLabel(f['sessionType'] ?? '')} - ${f['error']}')),
                    ]),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK')),
            ],
          ),
        );
      }
      await _loadSessionData();
    } else {
      _showSnack(res.message ?? 'Erro ao atualizar', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 3)),
    );
  }

  String _sessionLabel(String type) {
    switch (type) {
      case 'FP1':
        return 'TL1';
      case 'FP2':
        return 'TL2';
      case 'FP3':
        return 'TL3';
      case 'qualifying':
        return 'Classificacao';
      case 'sprint_qualifying':
        return 'Classif. Sprint';
      case 'sprint':
        return 'Sprint';
      case 'race':
        return 'Corrida';
      default:
        return type;
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Race list sidebar
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                child: const Text('Selecione a Corrida',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed)),
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
                            selectedTileColor:
                                AppTheme.primaryRed.withValues(alpha: 0.1),
                            title: Text(
                                race['name'] ?? 'Corrida ${race['round']}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            subtitle: Text(
                                'R${race['round']} - ${race['season']}',
                                style: const TextStyle(fontSize: 11)),
                            trailing: race['isCompleted'] == true ||
                                    race['is_completed'] == true
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 16)
                                : (race['isSprintWeekend'] == true ||
                                        race['is_sprint_weekend'] == true
                                    ? const Icon(Icons.bolt,
                                        color: Colors.orange, size: 16)
                                    : null),
                            onTap: () => _selectRace(race['id'] as int),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Content
        Expanded(
          child: _selectedRaceId == null
              ? const Center(
                  child: Text('Selecione uma corrida',
                      style: TextStyle(color: AppTheme.textSecondary)))
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
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.cardBackground,
          child: Row(
            children: [
              Text(_raceInfo?['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_raceInfo?['isSprintWeekend'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('SPRINT',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold)),
                ),
              if (_raceInfo?['isCompleted'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('FINALIZADA',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ),
              ],
              const Spacer(),
              // Refresh all sessions button
              ElevatedButton.icon(
                onPressed: _refreshingAll ? null : _refreshAllSessions,
                icon: _refreshingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_download, size: 18),
                label: Text(
                    _refreshingAll ? 'Atualizando...' : 'Atualizar Todas'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700),
              ),
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
            tabs: _availableSessions
                .map((s) => Tab(text: _sessionLabel(s)))
                .toList(),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children:
                _availableSessions.map((s) => _buildSessionTab(s)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTab(String sessionType) {
    final entries = _editingEntries[sessionType] ?? [];
    final session = _sessions[sessionType];
    final updatedAt = session?['updatedAt'];
    final isRace = sessionType == 'race';
    final hasResults =
        (session?['results'] as List?)?.isNotEmpty ?? false;

    return Column(
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Save button
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _saveSession(sessionType),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Salvando...' : 'Salvar Resultados'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
              ),
              const SizedBox(width: 8),
              // Reset order
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _editingEntries[sessionType] = _buildEntries(sessionType);
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Resetar'),
              ),
              const SizedBox(width: 8),
              // Auto-refresh toggle
              Builder(builder: (_) {
                final isThisActive = _autoRefreshActive &&
                    _autoRefreshRaceId == _selectedRaceId &&
                    _autoRefreshSessionType == sessionType;
                return _togglingAutoRefresh
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : isThisActive
                        ? ElevatedButton.icon(
                            onPressed: () => _toggleAutoRefresh(sessionType),
                            icon: const Icon(Icons.stop, size: 18),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Parar Auto-Refresh'),
                                if (_autoRefreshLastRefresh != null)
                                  Text(
                                    '${_autoRefreshSource == 'scheduler' ? '[Auto] ' : ''}Ultimo: ${_formatTime(_autoRefreshLastRefresh!)}${_autoRefreshErrorCount > 0 ? ' (${_autoRefreshErrorCount} erros)' : ''}',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _toggleAutoRefresh(sessionType),
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Auto-Refresh'),
                          );
              }),
              const Spacer(),
              if (updatedAt != null)
                Text('Atualizado: ${_formatTime(updatedAt)}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              // Finalize (race only)
              if (isRace && hasResults) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _finalizeResults,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar para Pontuacao'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed),
                ),
              ],
            ],
          ),
        ),
        // Editable table
        if (entries.isEmpty)
          const Expanded(
              child: Center(
                  child: Text('Nenhum piloto encontrado.',
                      style: TextStyle(color: AppTheme.textSecondary))))
        else
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EditableResultsTable(
                  entries: entries,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = entries.removeAt(oldIndex);
                      entries.insert(newIndex, item);
                    });
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Data class for a driver entry in the editable table
class _DriverEntry {
  final dynamic driverId;
  final String name;
  final String fullName;
  String bestLapTime;
  String gap;

  _DriverEntry({
    required this.driverId,
    required this.name,
    required this.fullName,
    required this.bestLapTime,
    required this.gap,
  });
}

// Editable table widget with drag-to-reorder rows
class _EditableResultsTable extends StatelessWidget {
  final List<_DriverEntry> entries;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _EditableResultsTable({
    required this.entries,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40),
              SizedBox(
                  width: 50,
                  child: Text('POS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  flex: 3,
                  child: Text('PILOTO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(
                  flex: 3,
                  child: Text('VOLTA / GAP',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 40),
            ],
          ),
        ),
        // Rows
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          onReorder: onReorder,
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 4,
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(4),
              child: child,
            );
          },
          itemBuilder: (ctx, i) {
            final entry = entries[i];
            final pos = i + 1;
            return _DriverRow(
              key: ValueKey(entry.driverId),
              position: pos,
              entry: entry,
              isFirst: pos == 1,
            );
          },
        ),
      ],
    );
  }
}

// Single editable row
class _DriverRow extends StatelessWidget {
  final int position;
  final _DriverEntry entry;
  final bool isFirst;

  const _DriverRow({
    super.key,
    required this.position,
    required this.entry,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Row(
        children: [
          // Drag handle
          const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          // Position
          SizedBox(
            width: 42,
            child: _positionBadge(position),
          ),
          // Driver name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(entry.fullName,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // Lap time / Gap input
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: TextEditingController(
                    text: isFirst ? entry.bestLapTime : entry.gap),
                onChanged: (v) {
                  if (isFirst) {
                    entry.bestLapTime = v;
                    entry.gap = 'LEADER';
                  } else {
                    entry.gap = v;
                  }
                },
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: isFirst ? 'Ex: 1:23.456' : 'Ex: +0.234',
                  hintStyle:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade700)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade700)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryRed)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _positionBadge(int pos) {
    Color bg;
    Color fg;
    if (pos == 1) {
      bg = const Color(0xFFFFD700);
      fg = Colors.black;
    } else if (pos == 2) {
      bg = const Color(0xFFC0C0C0);
      fg = Colors.black;
    } else if (pos == 3) {
      bg = const Color(0xFFCD7F32);
      fg = Colors.white;
    } else {
      bg = Colors.grey.shade800;
      fg = Colors.white;
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$pos',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: fg)),
    );
  }
}
