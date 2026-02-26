import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela de Visualização do Palpite
/// Mostra a ordem dos pilotos já salva, com opções de edição se ainda não travado
class PredictionViewScreen extends StatefulWidget {
  final String raceId;
  const PredictionViewScreen({super.key, required this.raceId});

  @override
  State<PredictionViewScreen> createState() => _PredictionViewScreenState();
}

class _PredictionViewScreenState extends State<PredictionViewScreen> {
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  bool _isSaving = false;

  dynamic _race;
  List<dynamic> _predictions = []; // ordenado por predicted_position
  List<dynamic> _appliedLeagues = [];
  String? _lockType;
  int? _maxPoints;

  // Para edição de ligas
  List<dynamic> _myLeagues = [];
  dynamic _officialLeague;
  Set<String> _editLeagueIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final predRes = await _api.get('/predictions/race/${widget.raceId}');
    final raceRes = await _api.get('/races/${widget.raceId}');
    final leaguesRes = await _api.get('/leagues?raceId=${widget.raceId}');
    final officialRes = await _api.get('/races/${widget.raceId}/official-league');

    if (mounted) {
      setState(() {
        if (raceRes.success) _race = raceRes.data;

        if (predRes.success && predRes.data != null) {
          final data = predRes.data as Map<String, dynamic>;
          _predictions = List.from(data['predictions'] as List? ?? []);
          _appliedLeagues = List.from(data['appliedLeagues'] as List? ?? []);
          _lockType = data['lockType'] as String?;
          _maxPoints = data['maxPoints'] as int?;
          _editLeagueIds = _appliedLeagues
              .map((l) => l['league_id'] as String)
              .toSet();
        }

        if (leaguesRes.success && leaguesRes.data != null) {
          _myLeagues = List.from(leaguesRes.data as List);
        }

        if (officialRes.success && officialRes.data != null) {
          _officialLeague = officialRes.data;
        }

        _isLoading = false;
      });
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  // Retorna a data limite baseada no lock_type
  DateTime? get _lockDeadline {
    if (_race == null) return null;
    if (_lockType == 'fp1') {
      return _parseDate(_race['fp1Date'] ?? _race['fp1_date']);
    }
    if (_lockType == 'qualifying') {
      return _parseDate(_race['qualifyingDate'] ?? _race['qualifying_date']);
    }
    return _parseDate(_race['raceDate'] ?? _race['race_date']);
  }

  bool get _isLocked {
    final deadline = _lockDeadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  String _lockTypeLabel(String? type) {
    switch (type) {
      case 'fp1': return 'Antes do TL1';
      case 'qualifying': return 'Antes da Classificação';
      default: return 'Antes da Corrida';
    }
  }

  Color _lockTypeColor(String? type) {
    switch (type) {
      case 'fp1': return const Color(0xFFFFD700);
      case 'qualifying': return const Color(0xFF64C4FF);
      default: return AppTheme.primaryRed;
    }
  }

  IconData _lockTypeIcon(String? type) {
    switch (type) {
      case 'fp1': return Icons.rocket_launch;
      case 'qualifying': return Icons.speed;
      default: return Icons.flag;
    }
  }

  // ── Editar Prazo ────────────────────────────────────────────
  Future<void> _showEditLockSheet() async {
    String tempLockType = _lockType ?? 'race';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final fp1 = _parseDate(_race?['fp1Date'] ?? _race?['fp1_date']);
          final quali = _parseDate(_race?['qualifyingDate'] ?? _race?['qualifying_date']);
          final raceDate = _parseDate(_race?['raceDate'] ?? _race?['race_date']);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Editar Prazo do Palpite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Quanto antes você travar, maior a pontuação máxima.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),

                _sheetLockOption(
                  ctx: ctx, setSheet: setSheet,
                  value: 'fp1', current: tempLockType,
                  label: 'Antes do TL1', points: 20,
                  dateStr: fp1 != null ? _formatDate(fp1) : 'Data não definida',
                  color: const Color(0xFFFFD700),
                  icon: Icons.rocket_launch,
                  isLocked: fp1 != null && DateTime.now().isAfter(fp1),
                  onChanged: (v) => setSheet(() => tempLockType = v),
                ),
                const SizedBox(height: 8),
                _sheetLockOption(
                  ctx: ctx, setSheet: setSheet,
                  value: 'qualifying', current: tempLockType,
                  label: 'Antes da Classificação', points: 15,
                  dateStr: quali != null ? _formatDate(quali) : 'Data não definida',
                  color: const Color(0xFF64C4FF),
                  icon: Icons.speed,
                  isLocked: quali != null && DateTime.now().isAfter(quali),
                  onChanged: (v) => setSheet(() => tempLockType = v),
                ),
                const SizedBox(height: 8),
                _sheetLockOption(
                  ctx: ctx, setSheet: setSheet,
                  value: 'race', current: tempLockType,
                  label: 'Antes da Corrida', points: 10,
                  dateStr: raceDate != null ? _formatDate(raceDate) : 'Data não definida',
                  color: AppTheme.primaryRed,
                  icon: Icons.flag,
                  isLocked: raceDate != null && DateTime.now().isAfter(raceDate),
                  onChanged: (v) => setSheet(() => tempLockType = v),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx, tempLockType);
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Confirmar Prazo'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((newLockType) async {
      if (newLockType != null && newLockType != _lockType) {
        await _saveLockType(newLockType as String);
      }
    });
  }

  Widget _sheetLockOption({
    required BuildContext ctx,
    required StateSetter setSheet,
    required String value,
    required String current,
    required String label,
    required int points,
    required String dateStr,
    required Color color,
    required IconData icon,
    required bool isLocked,
    required void Function(String) onChanged,
  }) {
    final isSelected = current == value;
    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isLocked ? null : () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade700,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.darkBackground,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(dateStr, style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text('$points pts', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (isLocked)
                const Icon(Icons.lock, size: 16, color: Colors.grey)
              else
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? color : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLockType(String newLockType) async {
    if (_predictions.isEmpty) return;
    setState(() => _isSaving = true);

    // Re-envia os palpites com o novo lock_type (mesma ordem)
    final preds = _predictions.map((p) => {
      'driver_id': p['driver_id'],
      'position': p['predicted_position'],
    }).toList();

    final res = await _api.post('/predictions', body: {
      'race_id': int.parse(widget.raceId),
      'predictions': preds,
      'lock_type': newLockType,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (res.success) {
        setState(() => _lockType = newLockType);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prazo atualizado!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Editar Ligas ────────────────────────────────────────────
  Future<void> _showEditLeaguesSheet() async {
    // Cria cópia do set atual para edição
    final tempIds = Set<String>.from(_editLeagueIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Combina liga oficial + minhas ligas (sem duplicar)
          final allLeagues = <dynamic>[];
          if (_officialLeague != null) allLeagues.add(_officialLeague);
          for (final l in _myLeagues) {
            if (l['id'] != _officialLeague?['id']) allLeagues.add(l);
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scroll) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Editar Ligas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Selecione as ligas onde quer aplicar seu palpite.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: allLeagues.length,
                      itemBuilder: (_, i) {
                        final league = allLeagues[i];
                        final id = league['id'] as String;
                        final isOff = league['is_official'] == true;
                        final isSelected = tempIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) => setSheet(() {
                            if (v == true) { tempIds.add(id); }
                            else { tempIds.remove(id); }
                          }),
                          title: Row(
                            children: [
                              if (isOff) ...[
                                const Icon(Icons.verified, color: AppTheme.primaryRed, size: 15),
                                const SizedBox(width: 6),
                              ],
                              Expanded(child: Text(league['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ),
                          subtitle: Text(
                            '${league['member_count'] ?? 0} membros${isOff ? ' • Liga oficial' : ''}',
                            style: TextStyle(fontSize: 12, color: isOff ? AppTheme.primaryRed.withValues(alpha: 0.8) : Colors.grey),
                          ),
                          activeColor: AppTheme.primaryRed,
                          secondary: Icon(isOff ? Icons.emoji_events : Icons.groups, color: isOff ? AppTheme.primaryRed : Colors.grey),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, tempIds),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        child: Text('Confirmar (${tempIds.length} ligas)'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((newIds) async {
      if (newIds != null) {
        await _applyLeagues(newIds as Set<String>);
      }
    });
  }

  Future<void> _applyLeagues(Set<String> leagueIds) async {
    if (leagueIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma liga'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSaving = true);

    final res = await _api.post('/predictions/apply', body: {
      'race_id': int.parse(widget.raceId),
      'league_ids': leagueIds.toList(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (res.success) {
        setState(() => _editLeagueIds = leagueIds);
        // Recarrega dados para refletir novas ligas aplicadas
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ligas atualizadas!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Apagar Palpite ──────────────────────────────────────────
  Future<void> _confirmDeletePrediction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar Palpite'),
        content: const Text(
          'Tem certeza que deseja apagar este palpite? '
          'Ele será removido de todas as ligas em que foi aplicado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final res = await _api.delete('/predictions/race/${widget.raceId}');
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Palpite apagado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Erro ao apagar palpite'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_race != null ? (_race['name'] ?? 'Meu Palpite') : 'Meu Palpite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Nenhum palpite encontrado'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/predictions/${widget.raceId}'),
              child: const Text('Fazer Palpite'),
            ),
          ],
        ),
      );
    }

    final lockColor = _lockTypeColor(_lockType);
    final deadline = _lockDeadline;
    final locked = _isLocked;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Card de Status ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: lockColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_lockTypeIcon(_lockType), color: lockColor, size: 20),
                  const SizedBox(width: 8),
                  Text(_lockTypeLabel(_lockType), style: TextStyle(color: lockColor, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: lockColor, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_maxPoints ?? '?'} pts/piloto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (locked)
                Row(
                  children: [
                    const Icon(Icons.lock, size: 15, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text('Palpite travado — não pode mais ser alterado',
                        style: TextStyle(color: Colors.orange, fontSize: 13)),
                  ],
                )
              else if (deadline != null)
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 15, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Prazo: ${_formatDate(deadline)}',
                          style: const TextStyle(color: Colors.green, fontSize: 13)),
                    ),
                  ],
                ),

              // Ligas aplicadas
              if (_appliedLeagues.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _appliedLeagues.map((l) => Chip(
                    label: Text(l['league_name'] ?? '', style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppTheme.surfaceColor,
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Botões de Edição ──────────────────────────────────
        if (!locked) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showEditLockSheet,
                  icon: const Icon(Icons.timer, size: 16),
                  label: const Text('Editar Prazo', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/predictions-edit-order/${widget.raceId}'),
                  icon: const Icon(Icons.drag_handle, size: 16),
                  label: const Text('Editar Ordem', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showEditLeaguesSheet,
                  icon: const Icon(Icons.groups, size: 16),
                  label: const Text('Editar Ligas', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmDeletePrediction,
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.primaryRed),
              label: const Text(
                'Apagar Palpite',
                style: TextStyle(fontSize: 12, color: AppTheme.primaryRed),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppTheme.primaryRed),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Lista de Pilotos ──────────────────────────────────
        Text('Sua Ordem de Chegada', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_predictions.length, (index) {
          final p = _predictions[index];
          final teamColor = _parseColor(p['team_color'] ?? '#666666');
          final pos = p['predicted_position'] as int? ?? index + 1;

          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: pos == 1 ? const Color(0xFFFFD700)
                          : pos == 2 ? const Color(0xFFC0C0C0)
                          : pos == 3 ? const Color(0xFFCD7F32)
                          : AppTheme.surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$pos',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: pos <= 3 ? Colors.black : Colors.white,
                          )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: teamColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: teamColor, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: p['photo_url'] != null
                        ? Image.network(
                            p['photo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, _) => Center(
                              child: Text('${p['number'] ?? '?'}',
                                  style: TextStyle(color: teamColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          )
                        : Center(
                            child: Text('${p['number'] ?? '?'}',
                                style: TextStyle(color: teamColor, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                  ),
                ],
              ),
              title: Text(
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                p['team_name'] ?? '',
                style: TextStyle(color: teamColor, fontSize: 11),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}
