import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

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
  String _membershipFilter = 'all'; // 'mine' | 'others' | 'all'
  String _statusFilter = 'active';  // 'active' | 'ended' | 'all'
  String? _selectedRaceId;
  String? _selectedRaceName;

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

  // Carrega a lista de GPs para o filtro
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
      // Apenas minhas ligas
      final raceQuery = _selectedRaceId != null ? '?raceId=$_selectedRaceId' : '';
      final res = await _api.get('/leagues$raceQuery');
      if (res.success && res.data != null) {
        result = (res.data as List).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          map['user_member_status'] = 'active';
          return map;
        }).toList();
        // Filtro de status no frontend para "minhas ligas"
        if (_statusFilter != 'all') {
          result = result.where((l) {
            final futureCount = int.tryParse(l['future_race_count']?.toString() ?? '0') ?? 0;
            if (_statusFilter == 'active') return futureCount > 0 || l['future_race_count'] == null;
            return futureCount == 0;
          }).toList();
        }
      }
    } else if (_membershipFilter == 'others') {
      // Ligas públicas excluindo as minhas
      final res = await _api.get('/leagues/public?$statusParam$raceParam');
      if (res.success && res.data != null) {
        final pubList = res.data as List;
        // Busca minhas ligas para excluir
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
      // Todas: minhas + públicas combinadas
      final futures = await Future.wait([
        _api.get('/leagues${_selectedRaceId != null ? '?raceId=$_selectedRaceId' : ''}'),
        _api.get('/leagues/public?$statusParam$raceParam'),
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
    }
  }

  // ── Helpers de label ─────────────────────────────────────────────────────
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

  // ── Diálogo: Entrar com código ───────────────────────────────────────────
  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar com Código'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(hintText: 'Digite o código da liga'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                final response =
                    await _api.post('/leagues/join-by-code', body: {'code': code});
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(response.message),
                    backgroundColor: response.success ? Colors.green : Colors.red,
                  ));
                  if (response.success) _loadLeagues();
                }
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/leagues/create'),
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.add),
        label: const Text('Criar Liga'),
      ),
      body: Column(
        children: [
          // ── Barra de filtros ──────────────────────────────────────────
          Container(
            color: AppTheme.cardBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Filtro 1: Ligas
                  _FilterMenu(
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

                  // Filtro 2: Atividade
                  _FilterMenu(
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

                  // Filtro 3: GP
                  _FilterMenu(
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
                  const SizedBox(width: 6),

                  // Botão de código
                  IconButton(
                    icon: const Icon(Icons.link, size: 20),
                    tooltip: 'Entrar com código',
                    onPressed: _showJoinByCodeDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lista de ligas ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _leagues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.groups_outlined,
                                size: 64, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma liga encontrada',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tente outros filtros',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeagues,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _leagues.length,
                          itemBuilder: (context, index) =>
                              _buildLeagueCard(_leagues[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Retorna a contagem total de GPs de uma liga.
  /// Suporta tanto o campo `race_count` (getMyLeagues) quanto
  /// a soma de `future_race_count` + `past_race_count` (getPublicLeagues).
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/leagues/${league['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome + badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      league['name'] ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isMember)
                    _buildChip('Membro', AppTheme.successGreen)
                  else if (isPending)
                    _buildChip('Pendente', AppTheme.warningOrange),
                ],
              ),
              if (league['description'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  league['description'],
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Meta info
              Wrap(
                spacing: 12,
                children: [
                  if (league['owner_name'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          league['owner_name'],
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '${league['member_count'] ?? 0} membros',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '$raceCount GPs',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (league['my_points'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 13, color: AppTheme.accentGold),
                        const SizedBox(width: 3),
                        Text(
                          '${league['my_points']} pts',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (requiresApproval)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_outline,
                            size: 13, color: AppTheme.warningOrange),
                        SizedBox(width: 3),
                        Text(
                          'Requer aprovação',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.warningOrange),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Modelo interno de item de filtro ─────────────────────────────────────────

class _FilterItem {
  final String value;
  final String label;
  const _FilterItem(this.value, this.label);
}

// ── Widget de botão de filtro com menu suspenso ───────────────────────────────

class _FilterMenu extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final List<_FilterItem> items;
  final void Function(String value) onSelected;

  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryRed : AppTheme.textSecondary;
    final bgColor = active
        ? AppTheme.primaryRed.withValues(alpha: 0.12)
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
          items: items
              .map((item) => PopupMenuItem<String>(
                    value: item.value,
                    child: Text(item.label,
                        style: TextStyle(
                          color: item.label == label
                              ? AppTheme.primaryRed
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppTheme.primaryRed.withValues(alpha: 0.5)
                : AppTheme.textSecondary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
