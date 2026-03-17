import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/podium_badges.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

/// Tela de Ranking Global
/// Pontuação por GP (deduplicada entre ligas) com filtros de período
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final ApiClient _api = ApiClient();

  String _activeFilter = 'month';
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _customRange;

  List<dynamic> _ranking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR');
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    String queryParams = '';
    switch (_activeFilter) {
      case 'month':
        final m =
            '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
        queryParams = '?month=$m';
      case '30d':
        queryParams = '?preset=30d';
      case '60d':
        queryParams = '?preset=60d';
      case '90d':
        queryParams = '?preset=90d';
      case 'custom':
        if (_customRange != null) {
          final start = _customRange!.start.toUtc().toIso8601String();
          final end = _customRange!.end.toUtc().toIso8601String();
          queryParams = '?startDate=$start&endDate=$end';
        }
    }

    final res = await _api.get('/rankings/global$queryParams');
    if (mounted) {
      setState(() {
        _ranking = res.success && res.data != null ? (res.data as List) : [];
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TutorialBloc>().add(TutorialScreenVisited('rankings'));
        }
      });
    }
  }

  void _setFilter(String filter) {
    if (_activeFilter == filter) return;
    setState(() => _activeFilter = filter);
    if (filter == 'custom') {
      _pickDateRange();
    } else {
      _load();
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _load();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customRange,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.black,
              surface: AppTheme.cardBackground,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _customRange = picked);
      _load();
    }
  }

  String _monthLabel() {
    final formatter = DateFormat('MMMM yyyy', 'pt_BR');
    final label = formatter.format(_selectedMonth);
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Barra de filtros ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              SingleChildScrollView(
                key: TutorialKeys.rankingsFilters,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Mês', 'month'),
                    const SizedBox(width: 6),
                    _buildFilterChip('30 dias', '30d'),
                    const SizedBox(width: 6),
                    _buildFilterChip('60 dias', '60d'),
                    const SizedBox(width: 6),
                    _buildFilterChip('90 dias', '90d'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Personalizado', 'custom'),
                  ],
                ),
              ),

              if (_activeFilter == 'month') ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: AppTheme.textSecondary, size: 22),
                      onPressed: _prevMonth,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                    Text(
                      _monthLabel(),
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary, size: 22),
                      onPressed: _nextMonth,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                  ],
                ),
              ],

              if (_activeFilter == 'custom') ...[
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range,
                              size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Text(
                            _customRange != null
                                ? '${DateFormat('dd/MM/yyyy').format(_customRange!.start)} — ${DateFormat('dd/MM/yyyy').format(_customRange!.end)}'
                                : 'Selecionar período',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Lista do ranking ──────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const ShimmerList(itemCount: 8, itemHeight: 64)
              : _ranking.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.leaderboard_outlined,
                      title: 'Nenhuma pontuação neste período',
                      subtitle: 'Tente outro filtro ou período.',
                      action: TextButton(
                        onPressed: () {
                          setState(() {
                            _activeFilter = 'month';
                            _selectedMonth = DateTime.now();
                          });
                          _load();
                        },
                        child: const Text('Ver mês atual'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          // Pódio visual para top 3
                          if (_ranking.length >= 3) _buildPodium(),
                          // Lista restante
                          ..._ranking.asMap().entries.map((entry) {
                            final i = entry.key;
                            final data = entry.value as Map<String, dynamic>;
                            final position = data['position'] ?? (i + 1);
                            // Pular top 3 se já mostrados no pódio
                            if (_ranking.length >= 3 && position <= 3) {
                              return const SizedBox.shrink();
                            }
                            return _buildRankingRow(
                              position: position,
                              name: (data['displayName'] ?? data['display_name'] ?? 'Usuário').toString(),
                              avatar: (data['avatarUrl'] ?? data['avatar_url'])?.toString(),
                              points: int.tryParse(data['totalPoints']?.toString() ?? data['total_points']?.toString() ?? '0') ?? 0,
                              races: int.tryParse(data['racesPlayed']?.toString() ?? data['races_played']?.toString() ?? '0') ?? 0,
                              userId: data['userId'] ?? data['user_id'],
                              podiumStats: data['podiumStats'] as Map<String, dynamic>?,
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  /// Pódio visual com destaque para top 3
  Widget _buildPodium() {
    final top3 = _ranking.take(3).toList();
    // Ordem visual: 2° | 1° | 3°
    final second = top3[1] as Map<String, dynamic>;
    final first = top3[0] as Map<String, dynamic>;
    final third = top3[2] as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(opacity: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumColumn(second, 2, 80)),
          Expanded(child: _buildPodiumColumn(first, 1, 100)),
          Expanded(child: _buildPodiumColumn(third, 3, 70)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildPodiumColumn(Map<String, dynamic> data, int position, double height) {
    final name = (data['displayName'] ?? data['display_name'] ?? 'Usuário').toString();
    final avatar = (data['avatarUrl'] ?? data['avatar_url'])?.toString();
    final points = int.tryParse(data['totalPoints']?.toString() ?? data['total_points']?.toString() ?? '0') ?? 0;
    final userId = data['userId'] ?? data['user_id'];
    final color = AppTheme.podiumColor(position);
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    return GestureDetector(
      onTap: userId != null ? () => context.push('/users/$userId') : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Medal
          Text(medals[position]!, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: position == 1 ? 32 : 26,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.exo2(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: position == 1 ? 22 : 18,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            name.split(' ').first,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: position == 1 ? 14 : 12,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Points
          Text(
            '$points pts',
            style: GoogleFonts.exo2(
              fontSize: position == 1 ? 18 : 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          // Pedestal
          Container(
            width: double.infinity,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.podiumGradient(position),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$position°',
                style: GoogleFonts.exo2(
                  fontSize: position == 1 ? 28 : 22,
                  fontWeight: FontWeight.w900,
                  color: position == 2 ? const Color(0xFF1A1A2E) : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingRow({
    required int position,
    required String name,
    required String? avatar,
    required int points,
    required int races,
    required dynamic userId,
    Map<String, dynamic>? podiumStats,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: userId != null ? () => context.push('/users/$userId') : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Posição em círculo
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceColor,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Nome + corridas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        PodiumBadges.fromMap(podiumStats, fontSize: 11),
                      ],
                    ),
                    Text(
                      '$races ${races == 1 ? 'corrida' : 'corridas'}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Pontos
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$points',
                    style: GoogleFonts.exo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text('pts',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isActive = _activeFilter == filterKey;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setFilter(filterKey),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
