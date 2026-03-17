import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';

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

  Map<String, dynamic>? _raceInfo;
  List<String> _availableSessions = [];
  Map<String, dynamic> _sessions = {};
  TabController? _tabController;

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

    Map<String, dynamic>? nextRace;
    final now = DateTime.now().toUtc();
    for (final r in races) {
      final raceDate = DateTime.tryParse(r['raceDate'] ?? '');
      if (raceDate != null && !r['isCompleted'] && raceDate.isAfter(now.subtract(const Duration(days: 2)))) {
        nextRace = Map<String, dynamic>.from(r);
        break;
      }
    }

    nextRace ??= Map<String, dynamic>.from(races.last);
    final raceId = nextRace['id'] as int;

    if (_currentRaceId > 0) _socket.leaveRace(_currentRaceId);
    _currentRaceId = raceId;
    _socket.joinRace(raceId);

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
          _selectLatestTab();
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TutorialBloc>().add(TutorialScreenVisited('live'));
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.live_tv, size: 48, color: AppTheme.textSecondary),
            ),
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
        _buildHeader(),
        // Botão Resultados Anteriores
        Container(
          width: double.infinity,
          color: AppTheme.cardBackground,
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: OutlinedButton.icon(
            onPressed: () => context.go('/f1-results'),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Resultados Anteriores', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
            ),
          ),
        ),
        // Tabs de sessões
        if (_tabController != null)
          Container(
            key: TutorialKeys.liveSessionTabs,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: _availableSessions.length > 4,
              tabs: _availableSessions.map((s) => Tab(text: _sessionLabel(s))).toList(),
            ),
          ),
        // Conteúdo da sessão selecionada
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
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raceName,
                  style: AppTheme.displayStyle(fontSize: 18),
                ),
                if (sessionType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.glowShadow(blur: 6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sessão ativa: ${_sessionLabel(sessionType)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('Pts Provisórios', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  '$totalPts',
                  style: GoogleFonts.exo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty, size: 40, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text('${_sessionLabel(sessionType)} - Aguardando resultados',
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Os resultados aparecerão aqui quando o admin atualizar.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

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
          if (raceControl.isNotEmpty) _buildRaceControl(raceControl),
          if (updatedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.update, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Atualizado: ${_formatTime(updatedAt)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          _buildResultsTable(results, scoringMap),
        ],
      ),
    );
  }

  Widget _buildRaceControl(List<Map<String, dynamic>> messages) {
    return Padding(
      padding: const EdgeInsets.all(10),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: AppTheme.chipDecoration(flagColor),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 44,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 42,
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceColor.withValues(alpha: 0.5)),
        headingTextStyle: GoogleFonts.exo2(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
        columns: const [
          DataColumn(label: Text('P')),
          DataColumn(label: Text('Piloto')),
          DataColumn(label: Text('Equipe')),
          DataColumn(label: Text('Tempo')),
          DataColumn(label: Text('Gap')),
          DataColumn(label: Text('Pneu')),
          DataColumn(label: Text('Pits')),
          DataColumn(label: Text('Pts')),
        ],
        rows: results.map((r) {
          final driverId = r['driverId'] as int;
          final scoring = scoringMap[driverId];
          final pts = scoring?['provisionalPoints'] ?? 0;
          final predicted = scoring?['predictedPosition'];
          final pos = r['position'] as int? ?? 0;

          final ptsColor = pts > 15
              ? AppTheme.primaryGreen
              : pts >= 10
                  ? AppTheme.warningOrange
                  : pts > 0
                      ? AppTheme.accentCyan
                      : AppTheme.textSecondary;

          final teamColor = _parseColor(r['teamColor']);

          // Destaque para top 3
          Color? rowBg;
          if (pos == 1) {
            rowBg = const Color(0xFFFFD700).withValues(alpha: 0.04);
          } else if (pos == 2) rowBg = const Color(0xFFC0C0C0).withValues(alpha: 0.04);
          else if (pos == 3) rowBg = const Color(0xFFCD7F32).withValues(alpha: 0.04);

          return DataRow(
            color: rowBg != null ? WidgetStateProperty.all(rowBg) : null,
            cells: [
              DataCell(Text(
                '${r['position']}',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: pos <= 3 ? _medalColor(pos) : AppTheme.textPrimary,
                ),
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (teamColor != null)
                    Container(
                      width: 3, height: 20,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: teamColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text(r['abbreviation'] ?? '???',
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (predicted != null) ...[
                    const SizedBox(width: 4),
                    Text('(P$predicted)', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ],
              )),
              DataCell(Text(r['teamName'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              DataCell(Text(r['bestLapTime'] ?? '-', style: GoogleFonts.exo2(fontSize: 12))),
              DataCell(Text(r['gap'] ?? '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              DataCell(_buildTireChip(r['tireCompound'])),
              DataCell(Text('${r['pitStops'] ?? 0}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(
                '+$pts',
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13, color: ptsColor),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTireChip(String? compound) {
    if (compound == null || compound.isEmpty) return const Text('-', style: TextStyle(fontSize: 12));

    final color = switch (compound.toUpperCase()) {
      'SOFT' => Colors.red,
      'MEDIUM' => Colors.yellow,
      'HARD' => Colors.white,
      'INTERMEDIATE' => Colors.green,
      'WET' => Colors.blue,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(compound[0], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color _medalColor(int position) {
    if (position == 1) return const Color(0xFFFFD700);
    if (position == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
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
