import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';

/// Tela de Ligas — lista unificada com três filtros em menu suspenso:
/// 1. Ligas: Minhas / Outras / Todas
/// 2. Atividade: Ativas / Encerradas / Todas
/// 3. GP: lista completa de corridas ou "Todos"
class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  final ApiClient _api = ApiClient();

  // ── Filtros ──────────────────────────────────────────────────────────────
  String _membershipFilter = 'all';
  String _statusFilter = 'active';
  String? _selectedRaceId;
  String? _selectedRaceName;

  // ── Busca por nome ──────────────────────────────────────────────────────
  String _searchQuery = '';

  // ── Dados ────────────────────────────────────────────────────────────────
  List<dynamic> _leagues = [];
  List<dynamic> _allRaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRaces();
    _loadLeagues();
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/races/all');
    if (mounted && res.success && res.data != null) {
      setState(() => _allRaces = res.data as List);
    }
  }

  Future<void> _loadLeagues() async {
    setState(() => _isLoading = true);

    final raceParam = _selectedRaceId != null ? '&raceId=$_selectedRaceId' : '';
    final statusParam = _statusFilter != 'all' ? '&status=$_statusFilter' : '&status=all';

    List<dynamic> result = [];

    if (_membershipFilter == 'mine') {
      final params = <String>[];
      if (_selectedRaceId != null) params.add('raceId=$_selectedRaceId');
      params.add('status=$_statusFilter');
      final queryStr = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await _api.get('/leagues$queryStr');
      if (res.success && res.data != null) {
        result = (res.data as List).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          map['user_member_status'] = 'active';
          return map;
        }).toList();
      }
    } else if (_membershipFilter == 'others') {
      final res = await _api.get('/leagues/public?$statusParam$raceParam');
      if (res.success && res.data != null) {
        final pubList = res.data as List;
        final myRes = await _api.get('/leagues');
        final myIds = <dynamic>{};
        if (myRes.success && myRes.data != null) {
          for (final l in myRes.data as List) {
            myIds.add(l['id']);
          }
        }
        result = pubList.where((l) => !myIds.contains(l['id'])).toList();
      }
    } else {
      final myParams = <String>[];
      if (_selectedRaceId != null) myParams.add('raceId=$_selectedRaceId');
      myParams.add('status=$_statusFilter');
      final myQueryStr = myParams.isNotEmpty ? '?${myParams.join('&')}' : '';

      final futures = await Future.wait([
        _api.get('/leagues$myQueryStr'),
        _api.get('/leagues/public?status=$_statusFilter$raceParam'),
      ]);
      final myRes = futures[0];
      final pubRes = futures[1];

      final combined = <String, dynamic>{};

      if (myRes.success && myRes.data != null) {
        for (final item in myRes.data as List) {
          final map = Map<String, dynamic>.from(item as Map);
          map['user_member_status'] = 'active';
          combined[map['id'].toString()] = map;
        }
      }
      if (pubRes.success && pubRes.data != null) {
        for (final item in pubRes.data as List) {
          final map = Map<String, dynamic>.from(item as Map);
          final id = map['id'].toString();
          if (!combined.containsKey(id)) combined[id] = map;
        }
      }
      result = combined.values.toList();
    }

    if (mounted) {
      setState(() {
        _leagues = result;
        _isLoading = false;
      });
      _triggerTutorial();
    }
  }

  void _triggerTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TutorialBloc>().add(TutorialScreenVisited('leagues'));
      }
    });
  }

  String get _membershipLabel => switch (_membershipFilter) {
        'mine' => 'Minhas Ligas',
        'others' => 'Outras Ligas',
        _ => 'Todas as Ligas',
      };

  String get _statusLabel => switch (_statusFilter) {
        'ended' => 'Encerradas',
        'all' => 'Qualquer status',
        _ => 'Ativas',
      };

  String get _raceLabel => _selectedRaceName ?? 'Todos os GPs';

  List<dynamic> get _filteredLeagues {
    if (_searchQuery.isEmpty) return _leagues;
    final query = _searchQuery.toLowerCase();
    return _leagues.where((l) {
      final name = (l['name'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: TutorialKeys.leaguesCreateBtn,
        onPressed: () => context.go('/leagues/create'),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add),
        label: Text('Criar Liga', style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Barra de filtros ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              key: TutorialKeys.leaguesFilter,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: _membershipLabel,
                    icon: Icons.groups_outlined,
                    active: _membershipFilter != 'all',
                    items: const [
                      _FilterItem('all', 'Todas as Ligas'),
                      _FilterItem('mine', 'Minhas Ligas'),
                      _FilterItem('others', 'Outras Ligas'),
                    ],
                    onSelected: (value) {
                      setState(() => _membershipFilter = value);
                      _loadLeagues();
                    },
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: _statusLabel,
                    icon: Icons.access_time_outlined,
                    active: _statusFilter != 'active',
                    items: const [
                      _FilterItem('active', 'Ativas'),
                      _FilterItem('ended', 'Encerradas'),
                      _FilterItem('all', 'Qualquer status'),
                    ],
                    onSelected: (value) {
                      setState(() => _statusFilter = value);
                      _loadLeagues();
                    },
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: _raceLabel,
                    icon: Icons.flag_outlined,
                    active: _selectedRaceId != null,
                    items: [
                      const _FilterItem('__all__', 'Todos os GPs'),
                      ..._allRaces.map((r) => _FilterItem(
                            r['id'].toString(),
                            'R${r['round']} · ${r['name']}',
                          )),
                    ],
                    onSelected: (value) {
                      setState(() {
                        if (value == '__all__') {
                          _selectedRaceId = null;
                          _selectedRaceName = null;
                        } else {
                          _selectedRaceId = value;
                          final race = _allRaces.firstWhere(
                            (r) => r['id'].toString() == value,
                            orElse: () => null,
                          );
                          _selectedRaceName = race != null
                              ? 'R${race['round']} · ${race['name']}'
                              : null;
                        }
                      });
                      _loadLeagues();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Barra de busca por nome ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar liga por nome...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                ),
                isDense: true,
              ),
            ),
          ),

          // ── Lista de ligas ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : _filteredLeagues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.groups_outlined,
                                size: 56, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma liga encontrada',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tente outros filtros',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeagues,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _filteredLeagues.length,
                          itemBuilder: (context, index) =>
                              _buildLeagueCard(_filteredLeagues[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.cardBackground,
      highlightColor: AppTheme.surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: 5,
        itemBuilder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  int _getRaceCount(dynamic league) {
    if (league['race_count'] != null) {
      return int.tryParse(league['race_count'].toString()) ?? 0;
    }
    final future = int.tryParse(league['future_race_count']?.toString() ?? '0') ?? 0;
    final past = int.tryParse(league['past_race_count']?.toString() ?? '0') ?? 0;
    return future + past;
  }

  Widget _buildLeagueCard(dynamic league) {
    final memberStatus = league['user_member_status'] as String?;
    final isMember = memberStatus == 'active';
    final isPending = memberStatus == 'pending';
    final requiresApproval = league['requires_approval'] == true;
    final raceCount = _getRaceCount(league);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/leagues/${league['id']}', extra: isMember),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome + badge
                Row(
                  children: [
                    // Ícone da liga
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isMember
                            ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMember
                              ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                              : AppTheme.borderSubtle,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (league['name'] ?? '?')[0].toUpperCase(),
                          style: GoogleFonts.exo2(
                            color: isMember ? AppTheme.primaryGreen : AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            league['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          if (league['description'] != null)
                            Text(
                              league['description'],
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isMember)
                      _buildStatusBadge('Membro', AppTheme.successGreen)
                    else if (isPending)
                      _buildStatusBadge('Pendente', AppTheme.warningOrange),
                  ],
                ),
                const SizedBox(height: 12),
                // Meta info
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (league['owner_name'] != null)
                      _buildMeta(Icons.person_outline, league['owner_name']),
                    _buildMeta(Icons.people_outline, '${league['member_count'] ?? 0} membros'),
                    _buildMeta(Icons.flag_outlined, '$raceCount GPs'),
                    if (league['my_points'] != null)
                      _buildMeta(Icons.star, '${league['my_points']} pts',
                          color: AppTheme.accentGold),
                    if (requiresApproval)
                      _buildMeta(Icons.lock_outline, 'Requer aprovação',
                          color: AppTheme.warningOrange),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: AppTheme.chipDecoration(color),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMeta(IconData icon, String text, {Color? color}) {
    final c = color ?? AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: c,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Modelo interno de item de filtro ─────────────────────────────────────────

class _FilterItem {
  final String value;
  final String label;
  const _FilterItem(this.value, this.label);
}

// ── Widget de chip de filtro com menu suspenso ────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final List<_FilterItem> items;
  final void Function(String value) onSelected;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryGreen : AppTheme.textSecondary;
    final bgColor = active
        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
        : AppTheme.surfaceColor;

    return GestureDetector(
      onTapDown: (details) async {
        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay =
            Navigator.of(context).overlay!.context.findRenderObject()
                as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero),
                ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );

        final selected = await showMenu<String>(
          context: context,
          position: position,
          color: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderSubtle),
          ),
          items: items
              .map((item) => PopupMenuItem<String>(
                    value: item.value,
                    child: Text(item.label,
                        style: TextStyle(
                          color: item.label == label
                              ? AppTheme.primaryGreen
                              : AppTheme.textPrimary,
                          fontWeight: item.label == label
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ))
              .toList(),
        );
        if (selected != null) onSelected(selected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
