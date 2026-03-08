import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();

  bool _loading = true;
  String? _error;

  // Dados da corrida
  Map<String, dynamic>? _raceInfo;
  List<String> _availableSessions = [];
  Map<String, dynamic> _sessions = {};
  TabController? _tabController;

  // Scoring
  Map<String, dynamic>? _scoring;
  int _currentRaceId = 0;

  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadNextRace();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _socketSub?.cancel();
    if (_currentRaceId > 0) _socket.leaveRace(_currentRaceId);
    super.dispose();
  }

  Future<void> _loadNextRace() async {
    setState(() { _loading = true; _error = null; });

    // Busca proxima corrida
    final racesRes = await _api.get('/races/all');
    if (!mounted) return;

    if (!racesRes.success || racesRes.data == null) {
      setState(() { _loading = false; _error = 'Erro ao carregar corridas'; });
      return;
    }

    final races = racesRes.data as List? ?? [];
    if (races.isEmpty) {
      setState(() { _loading = false; _error = 'Nenhuma corrida encontrada'; });
      return;
    }

    // Encontra a corrida mais proxima (nao completada)
    Map<String, dynamic>? nextRace;
    final now = DateTime.now().toUtc();
    for (final r in races) {
      final raceDate = DateTime.tryParse(r['raceDate'] ?? '');
      if (raceDate != null && !r['isCompleted'] && raceDate.isAfter(now.subtract(const Duration(days: 2)))) {
        nextRace = Map<String, dynamic>.from(r);
        break;
      }
    }

    // Se nenhuma proxima, pega a ultima
    nextRace ??= Map<String, dynamic>.from(races.last);
    final raceId = nextRace['id'] as int;

    // Entra na sala socket
    if (_currentRaceId > 0) _socket.leaveRace(_currentRaceId);
    _currentRaceId = raceId;
    _socket.joinRace(raceId);

    // Escuta atualizacoes via socket
    _socketSub?.cancel();
    _socketSub = _socket.sessionResultsStream.listen((data) {
      if (data['raceId'] == _currentRaceId) {
        _loadSessionData();
        _loadScoring();
      }
    });

    await _loadSessionData();
    await _loadScoring();
  }

  Future<void> _loadSessionData() async {
    final res = await _api.get('/live/races/$_currentRaceId/sessions');
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final available = (data['availableSessions'] as List?)?.cast<String>() ?? [];
      final sessions = data['sessions'] as Map<String, dynamic>? ?? {};
      final race = data['race'] as Map<String, dynamic>?;

      setState(() {
        _raceInfo = race;
        _availableSessions = available;
        _sessions = sessions;
        _loading = false;

        if (_tabController == null || _tabController!.length != available.length) {
          _tabController?.dispose();
          _tabController = TabController(length: available.length, vsync: this);
          // Seleciona a aba com dados mais recentes
          _selectLatestTab();
        }
      });
    } else {
      setState(() { _loading = false; _error = res.message; });
    }
  }

  Future<void> _loadScoring() async {
    final res = await _api.get('/live/races/$_currentRaceId/live-scoring');
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => _scoring = res.data as Map<String, dynamic>);
    }
  }

  void _selectLatestTab() {
    if (_tabController == null || _availableSessions.isEmpty) return;
    // Encontra a ultima sessao que tem dados
    int latestIdx = 0;
    for (int i = _availableSessions.length - 1; i >= 0; i--) {
      final sess = _sessions[_availableSessions[i]];
      if (sess != null && (sess['results'] as List?)?.isNotEmpty == true) {
        latestIdx = i;
        break;
      }
    }
    _tabController!.index = latestIdx;
  }

  String _sessionLabel(String type) {
    switch (type) {
      case 'FP1': return 'TL1';
      case 'FP2': return 'TL2';
      case 'FP3': return 'TL3';
      case 'qualifying': return 'Classif.';
      case 'sprint_qualifying': return 'Classif. Sprint';
      case 'sprint': return 'Sprint';
      case 'race': return 'Corrida';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNextRace,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header com info da corrida e pontuacao provisoria
        _buildHeader(),
        // Tabs de sessoes
        if (_tabController != null)
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
        // Conteudo da sessao selecionada
        if (_tabController != null)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _availableSessions.map((s) => _buildSessionTab(s)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final raceName = _raceInfo?['name'] ?? 'Corrida';
    final totalPts = _scoring?['totalProvisionalPoints'] ?? 0;
    final sessionType = _scoring?['sessionType'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppTheme.cardBackground,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(raceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                if (sessionType != null)
                  Text('Sessao ativa: ${_sessionLabel(sessionType)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Text('Pts Provisorios', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                Text('$totalPts', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTab(String sessionType) {
    final session = _sessions[sessionType];
    final results = (session?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final raceControl = (session?['raceControl'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final updatedAt = session?['updatedAt'];

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('${_sessionLabel(sessionType)} - Aguardando resultados',
              style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text('Os resultados aparecerao aqui quando o admin atualizar.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    // Build scoring map for this session's drivers
    final scoringDrivers = (_scoring?['drivers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final scoringMap = <int, Map<String, dynamic>>{};
    for (final d in scoringDrivers) {
      scoringMap[d['driverId'] as int] = d;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSessionData();
        await _loadScoring();
      },
      child: ListView(
        children: [
          // Race control messages
          if (raceControl.isNotEmpty) _buildRaceControl(raceControl),
          // Timestamp
          if (updatedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Atualizado: ${_formatTime(updatedAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          // Results table
          _buildResultsTable(results, scoringMap),
        ],
      ),
    );
  }

  Widget _buildRaceControl(List<Map<String, dynamic>> messages) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: messages.take(5).map((msg) {
          final flag = msg['flag'] as String?;
          Color flagColor = Colors.grey;
          if (flag == 'YELLOW') flagColor = Colors.yellow;
          if (flag == 'RED') flagColor = Colors.red;
          if (flag == 'GREEN') flagColor = Colors.green;
          if (flag == 'SAFETY_CAR' || flag == 'VSC') flagColor = Colors.orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: flagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: flagColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                if (flag != null) ...[
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: flagColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(msg['message'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsTable(List<Map<String, dynamic>> results, Map<int, Map<String, dynamic>> scoringMap) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(AppTheme.cardBackground),
        columns: const [
          DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Piloto', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Equipe', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Tempo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Gap', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pneu', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pits', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pts', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed))),
        ],
        rows: results.map((r) {
          final driverId = r['driverId'] as int;
          final scoring = scoringMap[driverId];
          final pts = scoring?['provisionalPoints'] ?? 0;
          final predicted = scoring?['predictedPosition'];

          Color ptsColor = Colors.grey;
          if (pts > 15) {
            ptsColor = Colors.green;
          } else if (pts >= 10) ptsColor = Colors.orange;
          else if (pts > 0) ptsColor = AppTheme.primaryRed;

          final teamColor = _parseColor(r['teamColor']);

          return DataRow(
            cells: [
              DataCell(Text('${r['position']}', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (teamColor != null)
                    Container(width: 3, height: 20, margin: const EdgeInsets.only(right: 6), color: teamColor),
                  Text(r['abbreviation'] ?? '???', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (predicted != null) ...[
                    const SizedBox(width: 4),
                    Text('(P$predicted)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ],
              )),
              DataCell(Text(r['teamName'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              DataCell(Text(r['bestLapTime'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(r['gap'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(_buildTireChip(r['tireCompound'])),
              DataCell(Text('${r['pitStops'] ?? 0}', style: const TextStyle(fontSize: 12))),
              DataCell(Text('+$pts', style: TextStyle(fontWeight: FontWeight.bold, color: ptsColor))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTireChip(String? compound) {
    if (compound == null || compound.isEmpty) return const Text('-', style: TextStyle(fontSize: 12));

    Color color;
    switch (compound.toUpperCase()) {
      case 'SOFT': color = Colors.red;
      case 'MEDIUM': color = Colors.yellow;
      case 'HARD': color = Colors.white;
      case 'INTERMEDIATE': color = Colors.green;
      case 'WET': color = Colors.blue;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(compound[0], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
