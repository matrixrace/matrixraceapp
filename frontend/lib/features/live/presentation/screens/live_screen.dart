import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/api_error_widget.dart';
import '../../../../shared/widgets/status_chip.dart';

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
      return const ShimmerCardAndList(cardHeight: 120, listItemCount: 8, listItemHeight: 72);
    }

    if (_error != null) {
      return ApiErrorWidget(
        message: _error!,
        icon: Icons.live_tv,
        onRetry: _loadNextRace,
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
        gradient: AppTheme.cardGradient(opacity: 0.06),
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
                    padding: const EdgeInsets.only(top: 6),
                    child: StatusChip.live(label: 'AO VIVO · ${_sessionLabel(sessionType)}'),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: AppTheme.neonBorder(radius: 14),
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
      return EmptyStateWidget(
        icon: Icons.hourglass_empty,
        title: '${_sessionLabel(sessionType)} - Aguardando resultados',
        subtitle: 'Os resultados aparecerão aqui quando o admin atualizar.',
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
          // Driver cards em vez de DataTable
          ...results.asMap().entries.map((entry) =>
            _buildDriverCard(entry.value, scoringMap, entry.key),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceControl(List<Map<String, dynamic>> messages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: messages.take(5).map((msg) {
          final flag = msg['flag'] as String?;
          Color flagColor = Colors.grey;
          IconData flagIcon = Icons.flag_outlined;
          if (flag == 'YELLOW') { flagColor = Colors.yellow; flagIcon = Icons.warning_amber; }
          if (flag == 'RED') { flagColor = Colors.red; flagIcon = Icons.flag; }
          if (flag == 'GREEN') { flagColor = Colors.green; flagIcon = Icons.check_circle_outline; }
          if (flag == 'SAFETY_CAR' || flag == 'VSC') { flagColor = Colors.orange; flagIcon = Icons.local_taxi; }

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: AppTheme.chipDecoration(flagColor),
            child: Row(
              children: [
                Icon(flagIcon, size: 16, color: flagColor),
                const SizedBox(width: 8),
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

  /// Card individual por piloto — substitui o DataTable
  Widget _buildDriverCard(Map<String, dynamic> r, Map<int, Map<String, dynamic>> scoringMap, int index) {
    final driverId = r['driverId'] as int;
    final scoring = scoringMap[driverId];
    final pts = scoring?['provisionalPoints'] ?? 0;
    final predicted = scoring?['predictedPosition'];
    final pos = r['position'] as int? ?? 0;
    final teamColor = _parseColor(r['teamColor']);
    final tire = r['tireCompound'] as String?;

    final ptsColor = pts > 15
        ? AppTheme.primaryGreen
        : pts >= 10
            ? AppTheme.warningOrange
            : pts > 0
                ? AppTheme.accentCyan
                : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pos <= 3
              ? AppTheme.podiumColor(pos).withValues(alpha: 0.2)
              : AppTheme.borderSubtle,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Barra de cor da equipe
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: teamColor ?? AppTheme.textSecondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Posição
            Container(
              width: 44,
              alignment: Alignment.center,
              child: pos <= 3
                  ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppTheme.podiumGradient(pos),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$pos',
                          style: GoogleFonts.exo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: pos == 2 ? const Color(0xFF1A1A2E) : Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      '$pos',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
            ),
            // Info do piloto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          r['abbreviation'] ?? '???',
                          style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        if (predicted != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('P$predicted',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r['teamName'] ?? '',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Tempo e gap
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    r['bestLapTime'] ?? '-',
                    style: GoogleFonts.exo2(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r['gap'] ?? '-',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Pneu
            if (tire != null && tire.isNotEmpty)
              TireChip(compound: tire, size: 26)
            else
              const SizedBox(width: 26),
            const SizedBox(width: 10),
            // Pontos
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                '+$pts',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: ptsColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 30).ms).slideX(begin: 0.05, end: 0);
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
