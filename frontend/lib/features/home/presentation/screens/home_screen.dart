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
  final Set<int> _predictedRaceIds = {}; // corridas onde o usuário já fez palpite
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadUpcomingRaces();
    _loadMyPredictions();
    // Atualiza o timer a cada segundo
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Retorna o tempo restante até [target] como partes separadas
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

  // Formata dois dígitos: 5 → "05"
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

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
        // Próxima corrida
        if (_upcomingRaces.isNotEmpty) ...[
          Text(
            'Próxima Corrida',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          _buildNextRaceCard(_upcomingRaces[0]),
          const SizedBox(height: 24),
        ],

        // Calendário
        Text(
          'Calendário',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
    final fp1Date = DateTime.tryParse(race['fp1_date'] ?? race['fp1Date'] ?? '');
    final t = _timeUntil(fp1Date);

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
                  Text(
                    'Round ${race['round']}',
                    style: const TextStyle(color: AppTheme.primaryRed),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                race['name'] ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${race['location'] ?? ''} - ${race['country'] ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (race['circuit_name'] != null || race['circuitName'] != null)
                Text(
                  race['circuit_name'] ?? race['circuitName'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 16),
              // Temporizador para o TL1
              t.started
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_off, size: 14, color: AppTheme.textSecondary),
                          SizedBox(width: 6),
                          Text('TL1 já iniciado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_outlined, size: 13, color: AppTheme.primaryRed),
                              SizedBox(width: 4),
                              Text('TL1 começa em', style: TextStyle(fontSize: 11, color: AppTheme.primaryRed)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CountdownUnit(value: t.days, label: 'dias'),
                              _CountdownSeparator(),
                              _CountdownUnit(value: t.hours, label: 'horas'),
                              _CountdownSeparator(),
                              _CountdownUnit(value: t.minutes, label: 'min'),
                              _CountdownSeparator(),
                              _CountdownUnit(value: t.seconds, label: 'seg'),
                            ],
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is AuthAuthenticated) {
                      final raceId = race['id'] as int;
                      if (_predictedRaceIds.contains(raceId)) {
                        context.go('/predictions-view/$raceId');
                      } else {
                        context.go('/predictions/$raceId');
                      }
                    } else {
                      context.go('/login');
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

  Widget _buildRaceListItem(dynamic race) {
    final raceDate = DateTime.tryParse(race['race_date'] ?? race['raceDate'] ?? '');
    final dateStr = raceDate != null
        ? '${raceDate.day}/${raceDate.month}/${raceDate.year}'
        : '';
    final raceId = race['id'] as int;
    final hasPrediction = _predictedRaceIds.contains(raceId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              child: Text(
                '${race['round']}',
                style: const TextStyle(color: AppTheme.primaryRed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(race['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${race['location'] ?? ''} - $dateStr',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated) {
                        context.go('/predictions/$raceId');
                      } else {
                        context.go('/login');
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // Timer compacto para os itens da lista (uma linha)
  Widget _buildCompactCountdown(dynamic race) {
    final fp1Date = DateTime.tryParse(race['fp1_date'] ?? race['fp1Date'] ?? '');
    final t = _timeUntil(fp1Date);
    if (t.started) {
      return const Text('TL1 já iniciado',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary));
    }
    final text = t.days > 0
        ? '${t.days}d ${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s'
        : '${_twoDigits(t.hours)}h ${_twoDigits(t.minutes)}m ${_twoDigits(t.seconds)}s';
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 11, color: AppTheme.primaryRed),
        const SizedBox(width: 3),
        Text('TL1: $text',
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryRed, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Widgets auxiliares do countdown ─────────────────────────────────────────

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryRed,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  const _CountdownSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(':',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
    );
  }
}
