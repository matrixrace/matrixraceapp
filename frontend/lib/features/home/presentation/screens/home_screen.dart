import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
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

  // Retorna o tempo restante até [target]
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

  // Formata um DateTime como DD/MM/YYYY
  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // Retorna "DD/MM/YYYY – DD/MM/YYYY" ou só uma data se a outra for nula
  String _dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return _fmtDate(end!);
    if (end == null) return _fmtDate(start);
    // Se mesma data, mostra só uma
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return _fmtDate(start);
    }
    return '${_fmtDate(start)} – ${_fmtDate(end)}';
  }

  // Parseia datas do backend (suporta camelCase e snake_case)
  DateTime? _parse(dynamic race, String camel, String snake) =>
      DateTime.tryParse(race[camel] ?? race[snake] ?? '')?.toLocal();

  Future<void> _loadMyPredictions() async {
    final res = await _api.get('/predictions/me');
    if (mounted && res.success && res.data != null) {
      final list = res.data as List;
      setState(() {
        _predictedRaceIds.clear();
        for (final p in list) {
          final id = p['race_id'];
          if (id != null) _predictedRaceIds.add(id as int);
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
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUpcomingRaces();
        await _loadMyPredictions();
      },
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_upcomingRaces.isNotEmpty) ...[
          Text('Próxima Corrida', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _buildNextRaceCard(_upcomingRaces[0]),
          const SizedBox(height: 24),
        ],
        Text('Calendário', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (_upcomingRaces.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhuma corrida disponível no momento.\nO admin precisa cadastrar as corridas.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._upcomingRaces.skip(1).map(_buildRaceListItem),
      ],
    );
  }

  Widget _buildNextRaceCard(dynamic race) {
    final fp1Date  = _parse(race, 'fp1Date',        'fp1_date');
    final qualiDate = _parse(race, 'qualifyingDate', 'qualifying_date');
    final raceDate  = _parse(race, 'raceDate',       'race_date');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryRed.withValues(alpha: 0.3),
              AppTheme.cardBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Text('Round ${race['round']}',
                      style: const TextStyle(color: AppTheme.primaryRed)),
                ],
              ),
              const SizedBox(height: 12),
              Text(race['name'] ?? '',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              // Cidade + faixa de datas (TL1 → Corrida)
              Text(
                '${race['location'] ?? ''}  ·  ${_dateRange(fp1Date, raceDate)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (race['circuit_name'] != null || race['circuitName'] != null)
                Text(
                  race['circuit_name'] ?? race['circuitName'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 16),
              // Três temporizadores: TL1 / Qualificação / Corrida
              _buildCountdownRows(fp1Date, qualiDate, raceDate),
              const SizedBox(height: 12),
              SizedBox(
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
      ),
    );
  }

  /// Container com três linhas de countdown (TL1 / Qualificação / Corrida)
  Widget _buildCountdownRows(DateTime? fp1, DateTime? quali, DateTime? race) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _countdownRow(Icons.timer_outlined, 'TL1', fp1),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Colors.white10),
          _countdownRow(Icons.speed, 'Qualificação', quali),
          const Divider(height: 1, indent: 12, endIndent: 12, color: Colors.white10),
          _countdownRow(Icons.flag_outlined, 'Corrida', race),
        ],
      ),
    );
  }

  Widget _countdownRow(IconData icon, String label, DateTime? target) {
    final t = _timeUntil(target);
    final started = t.started;
    final color = started ? AppTheme.textSecondary : AppTheme.primaryRed;

    String timerText;
    if (started) {
      timerText = 'em andamento';
    } else if (t.days > 0) {
      timerText = '${t.days}d ${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
    } else {
      timerText = '${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            timerText,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: started ? FontWeight.normal : FontWeight.w600,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: Text('${race['round']}',
                  style: const TextStyle(color: AppTheme.primaryRed)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(race['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    dateStr.isNotEmpty
                        ? '${race['location'] ?? ''} - $dateStr'
                        : '${race['location'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  _buildCompactCountdown(race),
                ],
              ),
            ),
            const SizedBox(width: 8),
            hasPrediction
                ? TextButton.icon(
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated) {
                        context.go('/predictions-view/$raceId');
                      } else {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver Palpite',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => context.go('/predictions/$raceId'),
                  ),
          ],
        ),
      ),
    );
  }

  /// Compact countdown: mostra apenas o próximo evento ainda não iniciado
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
            ? '${t.days}d ${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s'
            : '${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
        return Row(
          children: [
            Icon(icon, size: 11, color: AppTheme.primaryRed),
            const SizedBox(width: 3),
            Text('$label: $text',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.w500)),
          ],
        );
      }
    }

    return const SizedBox.shrink(); // todos já iniciados
  }
}

