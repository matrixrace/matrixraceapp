import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_theme.dart';

/// Aba Corridas da área da liga
/// Exibe corridas com status de palpite e palpites revelados após o lock
class CorridasTab extends StatefulWidget {
  final String leagueId;

  const CorridasTab({super.key, required this.leagueId});

  @override
  State<CorridasTab> createState() => _CorridasTabState();
}

class _CorridasTabState extends State<CorridasTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  List<dynamic> _races = [];
  bool _isLoading = true;
  final Set<String> _expandedRaces = {};
  final Map<String, List<dynamic>> _revealedPredictions = {};
  final Set<String> _loadingRevealed = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res =
        await _api.get('/leagues/${widget.leagueId}/races-status');
    if (mounted) {
      setState(() {
        _races =
            res.success && res.data != null ? (res.data as List) : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRevealed(String raceId) async {
    if (_loadingRevealed.contains(raceId)) return;
    setState(() => _loadingRevealed.add(raceId));
    final res = await _api.get(
        '/leagues/${widget.leagueId}/predictions-revealed/$raceId');
    if (mounted) {
      setState(() {
        _loadingRevealed.remove(raceId);
        if (res.success && res.data != null) {
          _revealedPredictions[raceId] = res.data as List;
        }
      });
    }
  }

  bool _isLocked(Map<String, dynamic> race) {
    final fp1 = race['fp1_date'] != null
        ? DateTime.tryParse(race['fp1_date'].toString())
        : null;
    final quali = race['qualifying_date'] != null
        ? DateTime.tryParse(race['qualifying_date'].toString())
        : null;
    final raceDate = race['race_date'] != null
        ? DateTime.tryParse(race['race_date'].toString())
        : null;
    final lockDate = fp1 ?? quali ?? raceDate;
    return lockDate != null && lockDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_races.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_motorsports_outlined,
                size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Nenhuma corrida nesta liga.',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _races.length,
        itemBuilder: (context, i) {
          final race = _races[i] as Map<String, dynamic>;
          return _buildRaceCard(race);
        },
      ),
    );
  }

  Widget _buildRaceCard(Map<String, dynamic> race) {
    final raceId = race['id'].toString();
    final name = race['name'] as String? ?? '';
    final round = race['round'] as int? ?? 0;
    final isCompleted = race['is_completed'] == true;
    final hasPrediction = race['has_prediction'] == true;
    final predictionApplied = race['prediction_applied'] == true;
    final locked = _isLocked(race);

    final raceDate = race['race_date'] != null
        ? DateTime.tryParse(race['race_date'].toString())
        : null;
    final dateStr = raceDate != null
        ? '${raceDate.day.toString().padLeft(2, '0')}/${raceDate.month.toString().padLeft(2, '0')}/${raceDate.year}'
        : '';

    final isExpanded = _expandedRaces.contains(raceId);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: !locked && !isCompleted
            ? Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Badge da rodada
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted || locked
                        ? AppTheme.surfaceColor
                        : AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'R$round',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCompleted || locked
                          ? AppTheme.textSecondary
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // Status / Ação
                _buildRaceAction(race, locked, isCompleted,
                    hasPrediction, predictionApplied, raceId),
              ],
            ),
          ),

          // Palpites Revelados (acordeão)
          if (locked && isExpanded) ...[
            const Divider(height: 1),
            _buildRevealedSection(raceId),
          ],
        ],
      ),
    );
  }

  Widget _buildRaceAction(
      Map<String, dynamic> race,
      bool locked,
      bool isCompleted,
      bool hasPrediction,
      bool predictionApplied,
      String raceId) {
    if (isCompleted) {
      return TextButton(
        onPressed: () => _toggleRevealed(raceId),
        child: Text(
          _expandedRaces.contains(raceId)
              ? 'Ocultar'
              : 'Ver palpites',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    if (locked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline,
              size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => _toggleRevealed(raceId),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4)),
            child: Text(
              _expandedRaces.contains(raceId) ? 'Ocultar' : 'Ver palpites',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    }

    if (!hasPrediction) {
      return OutlinedButton(
        onPressed: () => context.push('/predictions/${race['id']}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          side: const BorderSide(color: AppTheme.primaryRed),
        ),
        child: const Text('Palpitar',
            style:
                TextStyle(fontSize: 12, color: AppTheme.primaryRed)),
      );
    }

    if (predictionApplied) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 12, color: Colors.green),
            SizedBox(width: 4),
            Text('Aplicado',
                style: TextStyle(fontSize: 11, color: Colors.green)),
          ],
        ),
      );
    }

    return OutlinedButton(
      onPressed: () => context.push('/predictions/${race['id']}'),
      style: OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      child: const Text('Ver palpite', style: TextStyle(fontSize: 12)),
    );
  }

  void _toggleRevealed(String raceId) {
    setState(() {
      if (_expandedRaces.contains(raceId)) {
        _expandedRaces.remove(raceId);
      } else {
        _expandedRaces.add(raceId);
        if (!_revealedPredictions.containsKey(raceId)) {
          _loadRevealed(raceId);
        }
      }
    });
  }

  Widget _buildRevealedSection(String raceId) {
    if (_loadingRevealed.contains(raceId)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final predictions = _revealedPredictions[raceId];
    if (predictions == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Os palpites ainda não foram revelados.',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Palpites da Rodada',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...predictions.map((p) {
            final member = p as Map<String, dynamic>;
            final name = member['display_name'] as String? ?? '';
            final avatar = member['avatar_url'] as String?;
            final preds = (member['predictions'] as List?) ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.surfaceColor,
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primaryRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        preds.isEmpty
                            ? const Text('Sem palpite',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))
                            : Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: preds.take(10).map((pred) {
                                  final pos = pred['position'] as int? ?? 0;
                                  final dName =
                                      pred['driverName'] as String? ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$pos. $dName',
                                      style: const TextStyle(
                                          fontSize: 10),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
