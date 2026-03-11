import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/podium_badges.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';

/// Tela de Ranking Global
/// Pontuação por GP (deduplicada entre ligas) com filtros de período
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final ApiClient _api = ApiClient();

  // Filtro ativo
  String _activeFilter = 'month'; // 'month' | '30d' | '60d' | '90d' | 'custom'
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _customRange;

  // Dados
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
          color: AppTheme.cardBackground,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              // Chips de filtro
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

              // Navegador de mês
              if (_activeFilter == 'month') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: AppTheme.textSecondary, size: 22),
                      onPressed: _prevMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      _monthLabel(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary, size: 22),
                      onPressed: _nextMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],

              // Exibição do range customizado
              if (_activeFilter == 'custom') ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
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
              ],
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0x14FFFFFF)),

        // ── Lista do ranking ──────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _ranking.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.leaderboard_outlined,
                              size: 64, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          const Text('Nenhuma pontuação neste período.',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _activeFilter = 'month';
                                _selectedMonth = DateTime.now();
                              });
                              _load();
                            },
                            child: const Text('Ver mês atual'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _ranking.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, i) {
                          final entry = _ranking[i] as Map<String, dynamic>;
                          final position = entry['position'] ?? (i + 1);
                          final name = entry['displayName'] ??
                              entry['display_name'] ??
                              'Usuário';
                          final avatar =
                              entry['avatarUrl'] ?? entry['avatar_url'];
                          final points = int.tryParse(
                                  entry['totalPoints']?.toString() ??
                                      entry['total_points']?.toString() ??
                                      '0') ??
                              0;
                          final races = int.tryParse(
                                  entry['racesPlayed']?.toString() ??
                                      entry['races_played']?.toString() ??
                                      '0') ??
                              0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: _positionWidget(position),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.surfaceColor,
                                  backgroundImage: avatar != null
                                      ? NetworkImage(avatar.toString())
                                      : null,
                                  child: avatar == null
                                      ? Text(
                                          name.toString().isNotEmpty
                                              ? name
                                                  .toString()[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: AppTheme.primaryRed,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(name.toString(),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          PodiumBadges.fromMap(
                                            entry['podiumStats'] as Map<String, dynamic>?,
                                            fontSize: 11,
                                          ),
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
                                Text(
                                  '$points',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: position <= 3
                                        ? _medalColor(position)
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('pts',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isActive = _activeFilter == filterKey;
    return GestureDetector(
      onTap: () => _setFilter(filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.5))
              : null,
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
    );
  }

  Widget _positionWidget(int position) {
    if (position == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 22));
    }
    if (position == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 22));
    }
    if (position == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 22));
    }
    return Text(
      '$position',
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary),
      textAlign: TextAlign.center,
    );
  }

  Color _medalColor(int position) {
    if (position == 1) return const Color(0xFFFFD700);
    if (position == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }
}
