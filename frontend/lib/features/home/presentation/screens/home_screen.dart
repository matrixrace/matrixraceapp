import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Tela Inicial
/// Mostra a próxima corrida e permite navegar para palpites, ligas e rankings
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _upcomingRaces = [];
  bool _isLoading = true;
  final Set<int> _predictedRaceIds = {};
  final Set<int> _unappliedRaceIds = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadUpcomingRaces();
    _loadMyPredictions();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  ({int days, int hours, int minutes, int seconds, bool started}) _timeUntil(DateTime? target) {
    if (target == null) return (days: 0, hours: 0, minutes: 0, seconds: 0, started: true);
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return (days: 0, hours: 0, minutes: 0, seconds: 0, started: true);
    return (
      days: diff.inDays,
      hours: diff.inHours % 24,
      minutes: diff.inMinutes % 60,
      seconds: diff.inSeconds % 60,
      started: false,
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return _fmtDate(end!);
    if (end == null) return _fmtDate(start);
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return _fmtDate(start);
    }
    return '${_fmtDate(start)} – ${_fmtDate(end)}';
  }

  DateTime? _parse(dynamic race, String camel, String snake) =>
      DateTime.tryParse(race[camel] ?? race[snake] ?? '')?.toLocal();

  Future<void> _loadMyPredictions() async {
    final res = await _api.get('/predictions/me');
    if (mounted && res.success && res.data != null) {
      final list = res.data as List;
      setState(() {
        _predictedRaceIds.clear();
        _unappliedRaceIds.clear();
        for (final p in list) {
          final id = p['race_id'];
          if (id != null) {
            _predictedRaceIds.add(id as int);
            final appliedCount = int.tryParse('${p['applied_count'] ?? 0}') ?? 0;
            if (appliedCount == 0) _unappliedRaceIds.add(id);
          }
        }
      });
    }
  }

  Future<void> _loadUpcomingRaces() async {
    final response = await _api.get('/races/upcoming');
    if (response.success && response.data != null) {
      setState(() {
        _upcomingRaces = response.data as List;
        _isLoading = false;
      });
      _triggerTutorial();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _triggerTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TutorialBloc>().add(TutorialScreenVisited('home'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUpcomingRaces();
        await _loadMyPredictions();
      },
      child: _isLoading ? const ShimmerCardAndList() : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_upcomingRaces.isNotEmpty) ...[
          Text(
            key: TutorialKeys.homeNextRace,
            'Próxima Corrida',
            style: AppTheme.displayStyle(fontSize: 22),
          ),
          const SizedBox(height: 12),
          _buildNextRaceCard(_upcomingRaces[0])
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0),
          const SizedBox(height: 28),
        ],
        Text(
          key: TutorialKeys.homeCalendar,
          'Calendário',
          style: AppTheme.displayStyle(fontSize: 18),
        ),
        const SizedBox(height: 12),
        if (_upcomingRaces.isEmpty)
          const EmptyStateWidget(
            icon: Icons.calendar_today_outlined,
            title: 'Nenhuma corrida disponível',
            subtitle: 'O admin precisa cadastrar as corridas.',
          )
        else
          ..._upcomingRaces.skip(1).toList().asMap().entries.map((entry) =>
            _buildRaceListItem(entry.value)
                .animate()
                .fadeIn(duration: 300.ms, delay: (entry.key * 60).ms)
                .slideX(begin: 0.04, end: 0),
          ),
      ],
    );
  }

  Widget _buildNextRaceCard(dynamic race) {
    final fp1Date  = _parse(race, 'fp1Date',        'fp1_date');
    final qualiDate = _parse(race, 'qualifyingDate', 'qualifying_date');
    final raceDate  = _parse(race, 'raceDate',       'race_date');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppTheme.cardGradient(opacity: 0.08),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Round badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: AppTheme.chipDecoration(AppTheme.primaryGreen),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, size: 14, color: AppTheme.primaryGreen),
                      const SizedBox(width: 5),
                      Text(
                        'ROUND ${race['round']}',
                        style: GoogleFonts.exo2(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              race['name'] ?? '',
              style: AppTheme.displayStyle(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${race['location'] ?? ''}  ·  ${_dateRange(fp1Date, raceDate)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (race['circuit_name'] != null || race['circuitName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 18),
                child: Text(
                  race['circuit_name'] ?? race['circuitName'] ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 18),
            // Três temporizadores
            _buildCountdownRows(fp1Date, qualiDate, raceDate),
            const SizedBox(height: 14),
            // Aviso de palpite não aplicado
            if (_unappliedRaceIds.contains(race['id'] as int))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: AppTheme.chipDecoration(AppTheme.warningOrange),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Palpite salvo, mas ainda não aplicado em nenhuma liga',
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            // Botão de palpite
            SizedBox(
              key: TutorialKeys.homePredictionBtn,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final raceId = race['id'] as int;
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated &&
                      _predictedRaceIds.contains(raceId)) {
                    context.go('/predictions-view/$raceId');
                  } else {
                    context.go('/predictions/$raceId');
                  }
                },
                icon: Icon(_predictedRaceIds.contains(race['id'] as int)
                    ? Icons.visibility
                    : Icons.edit),
                label: Text(_predictedRaceIds.contains(race['id'] as int)
                    ? 'Ver Palpite'
                    : 'Fazer Palpite'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownRows(DateTime? fp1, DateTime? quali, DateTime? race) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _countdownRow(Icons.timer_outlined, 'TL1', fp1, isFirst: true),
          Divider(height: 1, indent: 12, endIndent: 12, color: AppTheme.borderSubtle),
          _countdownRow(Icons.speed, 'Qualificação', quali),
          Divider(height: 1, indent: 12, endIndent: 12, color: AppTheme.borderSubtle),
          _countdownRow(Icons.flag_outlined, 'Corrida', race, isLast: true),
        ],
      ),
    );
  }

  Widget _countdownRow(IconData icon, String label, DateTime? target, {bool isFirst = false, bool isLast = false}) {
    final t = _timeUntil(target);
    final started = t.started;
    final color = started ? AppTheme.textSecondary : AppTheme.primaryGreen;

    String timerText;
    if (started) {
      timerText = 'em andamento';
    } else if (t.days > 0) {
      timerText = '${t.days}d ${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
    } else {
      timerText = '${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            timerText,
            style: GoogleFonts.exo2(
              fontSize: 13,
              color: color,
              fontWeight: started ? FontWeight.w400 : FontWeight.w600,
              fontFeatures: started ? null : const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceListItem(dynamic race) {
    final fp1Date  = _parse(race, 'fp1Date',  'fp1_date');
    final raceDate = _parse(race, 'raceDate', 'race_date');
    final dateStr  = _dateRange(fp1Date, raceDate);
    final raceId   = race['id'] as int;
    final hasPrediction = _predictedRaceIds.contains(raceId);
    final isUnapplied = _unappliedRaceIds.contains(raceId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final authState = context.read<AuthBloc>().state;
            if (hasPrediction && authState is AuthAuthenticated) {
              context.go('/predictions-view/$raceId');
            } else {
              context.go('/predictions/$raceId');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Round number
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      '${race['round']}',
                      style: GoogleFonts.exo2(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(race['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        dateStr.isNotEmpty
                            ? '${race['location'] ?? ''} · $dateStr'
                            : '${race['location'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      if (isUnapplied)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 12),
                              const SizedBox(width: 4),
                              const Text(
                                'Falta aplicar em uma liga',
                                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      _buildCompactCountdown(race),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (hasPrediction)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: AppTheme.chipDecoration(AppTheme.primaryGreen),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Text('Palpite',
                            style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCountdown(dynamic race) {
    final sessions = [
      ('TL1',         _parse(race, 'fp1Date',        'fp1_date'),        Icons.timer_outlined),
      ('Qualificação', _parse(race, 'qualifyingDate', 'qualifying_date'), Icons.speed),
      ('Corrida',     _parse(race, 'raceDate',        'race_date'),       Icons.flag_outlined),
    ];

    for (final (label, date, icon) in sessions) {
      final t = _timeUntil(date);
      if (!t.started) {
        final text = t.days > 0
            ? '${t.days}d ${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m'
            : '${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
        return Row(
          children: [
            Icon(icon, size: 11, color: AppTheme.primaryGreen),
            const SizedBox(width: 4),
            Text('$label: ',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            Text(text,
                style: GoogleFonts.exo2(
                    fontSize: 11,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600)),
          ],
        );
      }
    }

    return const SizedBox.shrink();
  }
}
