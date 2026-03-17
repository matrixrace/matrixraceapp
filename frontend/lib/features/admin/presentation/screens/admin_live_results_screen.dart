import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/services/feedback_service.dart';

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

  final Map<String, List<_DriverEntry>> _editingEntries = {};

  // Auto-refresh state
  bool _autoRefreshActive = false;
  int? _autoRefreshRaceId;
  String? _autoRefreshSessionType;
  String? _autoRefreshLastRefresh;
  int _autoRefreshErrorCount = 0;
  bool _togglingAutoRefresh = false;
  String? _autoRefreshSource;
  bool _refreshingAll = false;

  // Responsive sidebar
  bool _sidebarCollapsed = false;

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
        FeedbackService.warning(context, 'Auto-refresh parado');
      }
    } else {
      final res = await _api.post('/live/admin/auto-refresh/start', body: {
        'raceId': _selectedRaceId,
        'sessionType': sessionType,
        'intervalSeconds': 30,
      });
      if (mounted && res.success) {
        FeedbackService.success(context, 'Auto-refresh ativado (30s)');
      } else if (mounted) {
        FeedbackService.error(context, res.message);
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
      FeedbackService.success(context, 'Sessão ${_sessionLabel(sessionType)} salva!');
      await _loadSessionData();
    } else {
      FeedbackService.error(context, res.message);
    }
  }

  Future<void> _finalizeResults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Enviar para Pontuação'),
        content: const Text(
            'Isso vai copiar os resultados da corrida como oficiais e calcular a pontuação de todos os usuários. Continuar?'),
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
      FeedbackService.success(context, 'Pontuações calculadas com sucesso!');
      _loadSessionData();
    } else {
      FeedbackService.error(context, res.message);
    }
  }

  Future<void> _toggleSprint() async {
    if (_selectedRaceId == null || _raceInfo == null) return;
    final current = _raceInfo!['isSprintWeekend'] == true;
    final res = await _api.put('/admin/races/$_selectedRaceId', body: {
      'isSprintWeekend': !current,
    });
    if (!mounted) return;
    if (res.success) {
      FeedbackService.info(context,
          !current ? 'Sprint Weekend ativado' : 'Sprint Weekend desativado');
      _editingEntries.clear();
      await _loadSessionData();
      _loadRaces();
    } else {
      FeedbackService.error(context, res.message);
    }
  }

  Future<void> _syncSchedule() async {
    final year = DateTime.now().year;
    final res =
        await _api.post('/admin/races/sync-schedule?year=$year');
    if (!mounted) return;
    if (res.success) {
      FeedbackService.success(context, 'Calendário $year sincronizado!');
      _loadRaces();
      if (_selectedRaceId != null) {
        _editingEntries.clear();
        _loadSessionData();
      }
    } else {
      FeedbackService.error(context, res.message);
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
      FeedbackService.error(context, res.message);
    }
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
        return 'Classificação';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 700;

    // On narrow screens, show sidebar as a drawer-like overlay or collapsed
    if (isNarrow && _selectedRaceId != null) {
      // Show only content with a back button
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: AppTheme.cardBackground,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedRaceId = null),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar às corridas',
                ),
                Expanded(
                  child: Text(
                    _raceInfo?['name'] ?? 'Corrida',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingSessions
                ? const ShimmerList(itemCount: 6, itemHeight: 48)
                : _buildSessionContent(),
          ),
        ],
      );
    }

    if (isNarrow) {
      // Show only race list
      return _buildRaceSidebar(expanded: true);
    }

    // Desktop: sidebar + content
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebarCollapsed ? 0 : 260,
          child: _sidebarCollapsed
              ? const SizedBox.shrink()
              : _buildRaceSidebar(expanded: true),
        ),
        if (!_sidebarCollapsed) const VerticalDivider(width: 1),
        Expanded(
          child: _selectedRaceId == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_sidebarCollapsed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            onPressed: () => setState(() => _sidebarCollapsed = false),
                            icon: const Icon(Icons.menu),
                            tooltip: 'Mostrar corridas',
                          ),
                        ),
                      const EmptyStateWidget(
                        icon: Icons.live_tv_outlined,
                        title: 'Selecione uma corrida',
                        subtitle: 'Escolha uma corrida na lista ao lado para gerenciar resultados ao vivo.',
                        iconSize: 40,
                      ),
                    ],
                  ),
                )
              : _loadingSessions
                  ? const ShimmerList(itemCount: 6, itemHeight: 48)
                  : Column(
                      children: [
                        if (_sidebarCollapsed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            color: AppTheme.cardBackground,
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => setState(() => _sidebarCollapsed = false),
                                  icon: const Icon(Icons.menu),
                                  tooltip: 'Mostrar corridas',
                                ),
                                Text(
                                  _raceInfo?['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        Expanded(child: _buildSessionContent()),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildRaceSidebar({required bool expanded}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.primaryRed.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Expanded(
                child: Text('Selecione a Corrida',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed)),
              ),
              IconButton(
                onPressed: _syncSchedule,
                icon: const Icon(Icons.sync, size: 18),
                tooltip: 'Sincronizar calendário F1',
                color: AppTheme.primaryRed,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              if (!MediaQuery.of(context).size.width.isNaN &&
                  MediaQuery.of(context).size.width >= 700)
                IconButton(
                  onPressed: () => setState(() => _sidebarCollapsed = true),
                  icon: const Icon(Icons.chevron_left, size: 18),
                  tooltip: 'Recolher sidebar',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingRaces
              ? const ShimmerList(itemCount: 8, itemHeight: 48)
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
    );
  }

  Widget _buildSessionContent() {
    if (_availableSessions.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.timer_off_outlined,
          title: 'Nenhuma sessão disponível',
          subtitle: 'Configure o tipo de corrida (normal/sprint) para habilitar as sessões.',
          iconSize: 40,
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.cardBackground,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_raceInfo?['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              // Sprint toggle
              InkWell(
                onTap: _toggleSprint,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _raceInfo?['isSprintWeekend'] == true
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _raceInfo?['isSprintWeekend'] == true
                              ? Colors.orange
                              : Colors.grey,
                          width: 0.5)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt,
                          size: 12,
                          color: _raceInfo?['isSprintWeekend'] == true
                              ? Colors.orange
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                          _raceInfo?['isSprintWeekend'] == true
                              ? 'SPRINT'
                              : 'Normal',
                          style: TextStyle(
                              fontSize: 10,
                              color: _raceInfo?['isSprintWeekend'] == true
                                  ? Colors.orange
                                  : Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (_raceInfo?['isCompleted'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('FINALIZADA',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                                    '${_autoRefreshSource == 'scheduler' ? '[Auto] ' : ''}Último: ${_formatTime(_autoRefreshLastRefresh!)}${_autoRefreshErrorCount > 0 ? ' ($_autoRefreshErrorCount erros)' : ''}',
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
              if (updatedAt != null)
                Text('Atualizado: ${_formatTime(updatedAt)}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              // Finalize (race only)
              if (isRace && hasResults)
                ElevatedButton.icon(
                  onPressed: _finalizeResults,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar para Pontuação'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed),
                ),
            ],
          ),
        ),
        // Editable table
        if (entries.isEmpty)
          const Expanded(
              child: Center(
                  child: EmptyStateWidget(
                    icon: Icons.person_off_outlined,
                    title: 'Nenhum piloto encontrado',
                    subtitle: 'Sincronize os pilotos primeiro.',
                    iconSize: 36,
                  )))
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
          const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: _positionBadge(position),
          ),
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
