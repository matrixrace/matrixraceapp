import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Tela de Palpite - 3 passos:
/// Passo 1: Ordenar os 22 pilotos
/// Passo 2: Escolher quando travar o palpite (FP1/Quali/Corrida)
/// Passo 3: Aplicar em ligas
class PredictionScreen extends StatefulWidget {
  final String raceId;
  /// Quando true, exibe apenas o passo de ordenação e salva diretamente,
  /// sem passar pelo passo de prazo ou ligas.
  final bool editOrderOnly;

  const PredictionScreen({super.key, required this.raceId, this.editOrderOnly = false});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  bool _isSaving = false;

  dynamic _race;
  dynamic _officialLeague; // Liga oficial deste GP
  List<dynamic> _drivers = [];
  List<dynamic> _myLeagues = [];
  List<dynamic> _publicLeagues = []; // Ligas públicas disponíveis (usuário não é membro)

  // Passo atual: 1, 2 ou 3
  int _currentStep = 1;

  // Escolha do lock_type no passo 2
  String _selectedLockType = 'race';

  // Ligas selecionadas no passo 3
  final Set<String> _selectedLeagueIds = {};

  String? _savedLockType;

  // Ordenação rápida
  bool _isLoadingQuickOrder = false;
  bool _hasPreviousPrediction = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final raceRes = await _api.get('/races/${widget.raceId}');
    final driversRes = await _api.get('/races/drivers');
    final leaguesRes = await _api.get('/leagues?raceId=${widget.raceId}');
    final myPredRes = await _api.get('/predictions/race/${widget.raceId}');
    final officialLeagueRes = await _api.get('/races/${widget.raceId}/official-league');
    final publicLeaguesRes = await _api.get('/leagues/public-for-prediction?raceId=${widget.raceId}');
    final allPredsRes = await _api.get('/predictions/me');

    if (mounted) {
      setState(() {
        if (raceRes.success) _race = raceRes.data;

        if (driversRes.success && driversRes.data != null) {
          _drivers = List.from(driversRes.data as List);
        }

        if (leaguesRes.success && leaguesRes.data != null) {
          _myLeagues = List.from(leaguesRes.data as List);
        }

        if (publicLeaguesRes.success && publicLeaguesRes.data != null) {
          _publicLeagues = List.from(publicLeaguesRes.data as List);
        }

        // Liga oficial deste GP (pré-selecionada por padrão)
        if (officialLeagueRes.success && officialLeagueRes.data != null) {
          _officialLeague = officialLeagueRes.data;
          // Pré-seleciona a liga oficial automaticamente
          final officialId = _officialLeague['id'] as String?;
          if (officialId != null) _selectedLeagueIds.add(officialId);
        }

        // Se já tem palpite, pré-preenche a ordem dos pilotos e lockType
        if (myPredRes.success && myPredRes.data != null) {
          final data = myPredRes.data as Map<String, dynamic>;
          final savedPreds = data['predictions'] as List? ?? [];
          if (savedPreds.isNotEmpty) {
            _savedLockType = data['lockType'];
            _selectedLockType = _savedLockType ?? 'race';

            // Reordena pilotos conforme palpite salvo
            final orderedDriverIds = savedPreds
              ..sort((a, b) => (a['predicted_position'] as int).compareTo(b['predicted_position'] as int));

            final reordered = <dynamic>[];
            for (final pred in orderedDriverIds) {
              final driver = _drivers.firstWhere(
                (d) => d['id'] == pred['driver_id'],
                orElse: () => null,
              );
              if (driver != null) reordered.add(driver);
            }
            // Adiciona pilotos que não estão no palpite ao final
            for (final d in _drivers) {
              if (!reordered.any((r) => r['id'] == d['id'])) {
                reordered.add(d);
              }
            }
            _drivers = reordered;

            // Pré-seleciona ligas já aplicadas
            final appliedLeagues = data['appliedLeagues'] as List? ?? [];
            for (final l in appliedLeagues) {
              _selectedLeagueIds.add(l['league_id'] as String);
            }
          }
        }

        // Verifica se usuário tem palpite anterior (para habilitar "Último Palpite")
        if (allPredsRes.success && allPredsRes.data != null) {
          final allPreds = allPredsRes.data as List;
          _hasPreviousPrediction = allPreds.any(
            (p) => p['race_id'].toString() != widget.raceId,
          );
        }

        _isLoading = false;
      });
    }
  }

  // ── Ordenação Rápida ───────────────────────────────────────────
  Future<void> _applyQuickOrder(String type) async {
    setState(() => _isLoadingQuickOrder = true);

    final res = await _api.get(
      '/predictions/quick-order?raceId=${widget.raceId}&type=$type',
    );

    if (!mounted) return;
    setState(() => _isLoadingQuickOrder = false);

    if (!res.success || res.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Erro ao carregar ordem'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final orderedIds = (res.data['orderedDriverIds'] as List? ?? [])
        .map((e) => e as int)
        .toList();

    if (orderedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado disponível para este GP')),
      );
      return;
    }

    setState(() {
      final reordered = <dynamic>[];
      for (final id in orderedIds) {
        final driver = _drivers.firstWhere(
          (d) => d['id'] == id,
          orElse: () => null,
        );
        if (driver != null) reordered.add(driver);
      }
      // Pilotos não cobertos ficam no final
      for (final d in _drivers) {
        if (!reordered.any((r) => r['id'] == d['id'])) reordered.add(d);
      }
      _drivers = reordered;
    });
  }

  Widget _buildQuickOrderButtons() {
    final isRound1 = (_race?['round'] as int? ?? 1) == 1;

    return Container(
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: _isLoadingQuickOrder
          ? const Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Autocompletar',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _QuickBtn(
                        'Última Corrida',
                        Icons.history,
                        onTap: isRound1 ? null : () => _applyQuickOrder('last-race'),
                      ),
                      _QuickBtn(
                        'Campeonato',
                        Icons.military_tech,
                        onTap: isRound1 ? null : () => _applyQuickOrder('standings'),
                      ),
                      _QuickBtn(
                        'Último Palpite',
                        Icons.bookmark_outline,
                        onTap: _hasPreviousPrediction
                            ? () => _applyQuickOrder('last-prediction')
                            : null,
                      ),
                      _QuickBtn(
                        'Por IA',
                        Icons.auto_awesome,
                        onTap: null, // desabilitado — futuro
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return 'Data não definida';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _savePrediction() async {
    if (_drivers.isEmpty) return;
    setState(() => _isSaving = true);

    final preds = _drivers.asMap().entries.map((e) => {
      'driver_id': e.value['id'],
      'position': e.key + 1,
    }).toList();

    final response = await _api.post('/predictions', body: {
      'race_id': int.parse(widget.raceId),
      'predictions': preds,
      'lock_type': _selectedLockType,
    });

    setState(() => _isSaving = false);

    if (mounted) {
      if (response.success) {
        if (widget.editOrderOnly) {
          // Volta direto para a tela de visualização após salvar a nova ordem
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ordem atualizada!'), backgroundColor: Colors.green),
          );
          context.go('/predictions-view/${widget.raceId}');
          return;
        }
        setState(() {
          _savedLockType = _selectedLockType;
          _currentStep = 3;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Palpite salvo!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message.isNotEmpty ? response.message : 'Erro ao salvar'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _applyToLeagues() async {
    if (_selectedLeagueIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma liga'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    final response = await _api.post('/predictions/apply', body: {
      'race_id': int.parse(widget.raceId),
      'league_ids': _selectedLeagueIds.toList(),
    });

    setState(() => _isSaving = false);

    if (mounted) {
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Palpite aplicado em ${_selectedLeagueIds.length} liga(s)!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/predictions-view/${widget.raceId}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_race != null ? (_race['name'] ?? 'Palpite') : 'Palpite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.editOrderOnly) {
              context.go('/predictions-view/${widget.raceId}');
            } else if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!widget.editOrderOnly) _buildStepIndicator(),
                Expanded(child: _buildCurrentStep()),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          _stepDot(1, 'Palpite'),
          Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppTheme.primaryRed : Colors.grey.shade700)),
          _stepDot(2, 'Prazo'),
          Expanded(child: Container(height: 2, color: _currentStep >= 3 ? AppTheme.primaryRed : Colors.grey.shade700)),
          _stepDot(3, 'Ligas'),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? Colors.green : isActive ? AppTheme.primaryRed : Colors.grey.shade700,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? AppTheme.primaryRed : Colors.grey)),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Drivers();
      case 2:
        return _buildStep2LockType();
      case 3:
        return _buildStep3Leagues();
      default:
        return const SizedBox();
    }
  }

  // PASSO 1: Ordenar pilotos
  Widget _buildStep1Drivers() {
    return Column(
      children: [
        _buildQuickOrderButtons(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.primaryRed.withValues(alpha: 0.1),
          child: const Row(
            children: [
              Icon(Icons.drag_indicator, color: AppTheme.primaryRed, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arraste os pilotos para colocá-los na ordem que você acha que vão terminar',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: _drivers.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final driver = _drivers.removeAt(oldIndex);
                _drivers.insert(newIndex, driver);
              });
            },
            itemBuilder: (context, index) {
              final driver = _drivers[index];
              final teamColor = _parseColor(driver['team_color'] ?? '#666666');

              return Card(
                key: ValueKey(driver['id']),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Posição (círculo com medalha para pódio)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index == 0 ? const Color(0xFFFFD700) : index == 1 ? const Color(0xFFC0C0C0) : index == 2 ? const Color(0xFFCD7F32) : AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: index < 3 ? Colors.black : Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Foto do piloto
                      _buildDriverPhoto(driver, teamColor),
                    ],
                  ),
                  title: Text('${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(driver['team_name'] ?? '', style: TextStyle(color: teamColor, fontSize: 12)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // PASSO 2: Escolher quando travar
  Widget _buildStep2LockType() {
    final fp1Date = _formatDate(_race?['fp1Date'] ?? _race?['fp1_date']);
    final qualiDate = _formatDate(_race?['qualifyingDate'] ?? _race?['qualifying_date']);
    final raceDate = _formatDate(_race?['raceDate'] ?? _race?['race_date']);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Quando você quer travar seu palpite?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quanto antes você travar, maior a pontuação máxima por piloto acertado.\nApós o prazo escolhido, não será mais possível alterar o palpite.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),

        _lockTypeCard(
          value: 'fp1',
          title: 'Antes do TL1',
          subtitle: fp1Date,
          points: 20,
          description: 'Máximo de 20 pontos por piloto acertado. Mais risco, mais recompensa!',
          icon: Icons.rocket_launch,
          color: const Color(0xFFFFD700),
        ),
        const SizedBox(height: 12),
        _lockTypeCard(
          value: 'qualifying',
          title: 'Antes da Classificação',
          subtitle: qualiDate,
          points: 15,
          description: 'Máximo de 15 pontos por piloto. Bom equilíbrio entre risco e pontuação.',
          icon: Icons.speed,
          color: const Color(0xFF64C4FF),
        ),
        const SizedBox(height: 12),
        _lockTypeCard(
          value: 'race',
          title: 'Antes da Corrida',
          subtitle: raceDate,
          points: 10,
          description: 'Máximo de 10 pontos por piloto. Mais seguro, mas pontuação menor.',
          icon: Icons.flag,
          color: AppTheme.primaryRed,
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fórmula: max(0, pontos_max − |posição_prevista − posição_real|)\nExemplo: prever 3º, piloto chegou em 5º = max(0, 20−2) = 18 pts (se TL1)',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockTypeCard({
    required String value,
    required String title,
    required String subtitle,
    required int points,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedLockType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedLockType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade700,
            width: isSelected ? 2.5 : 1,
          ),
          color: isSelected ? color.withValues(alpha: 0.08) : AppTheme.cardBackground,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$points pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? color : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // PASSO 3: Escolher ligas
  Widget _buildStep3Leagues() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aplicar em quais ligas?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Seu palpite será enviado para as ligas selecionadas.\nVocê pode aplicar em quantas quiser.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Resumo do palpite
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Palpite salvo • Travado: ${_lockTypeLabel(_selectedLockType)} • Max ${_lockTypePoints(_selectedLockType)} pts/piloto',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // --- Liga Oficial deste GP ---
              if (_officialLeague != null) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('LIGA OFICIAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryRed, letterSpacing: 1.2)),
                ),
                _buildLeagueCheckbox(_officialLeague, isOfficialCard: true),
                const SizedBox(height: 16),
              ],

              // --- Minhas Ligas ---
              if (_myLeagues.isNotEmpty) ...[
                if (_officialLeague != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('MINHAS LIGAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                // Filtra a liga oficial (já aparece acima)
                ..._myLeagues
                    .where((l) => l['id'] != _officialLeague?['id'])
                    .map((l) => _buildLeagueCheckbox(l)),
                const SizedBox(height: 8),
              ],

              // --- Outras Ligas Públicas ---
              if (_publicLeagues.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('OUTRAS LIGAS PÚBLICAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                ),
                ..._publicLeagues.map((l) => _buildLeagueCheckbox(l, isNewJoin: true)),
                const SizedBox(height: 8),
              ],

              if (_officialLeague == null && _myLeagues.isEmpty && _publicLeagues.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Você não está em nenhuma liga'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => context.go('/leagues'),
                        child: const Text('Criar ou Entrar em uma Liga'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueCheckbox(dynamic league, {bool isOfficialCard = false, bool isNewJoin = false}) {
    final leagueId = league['id'] as String;
    final isSelected = _selectedLeagueIds.contains(leagueId);
    final memberCount = league['member_count'] ?? 0;

    final Color accentColor = isOfficialCard
        ? AppTheme.primaryRed
        : isNewJoin
            ? Colors.blue
            : Colors.grey;

    String subtitleText = '$memberCount membros';
    if (isOfficialCard) subtitleText += ' • Entrada automática';
    if (isNewJoin) subtitleText += ' • Entrar + Aplicar';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isSelected
            ? BorderSide(color: accentColor, width: 1.5)
            : BorderSide.none,
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedLeagueIds.add(leagueId);
            } else {
              _selectedLeagueIds.remove(leagueId);
            }
          });
        },
        title: Row(
          children: [
            if (isOfficialCard) ...[
              const Icon(Icons.verified, color: AppTheme.primaryRed, size: 16),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                league['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isNewJoin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Nova',
                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(fontSize: 12, color: accentColor.withValues(alpha: 0.8)),
        ),
        activeColor: accentColor,
        secondary: Icon(
          isOfficialCard ? Icons.emoji_events : isNewJoin ? Icons.add_circle_outline : Icons.groups,
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // Modo edição de ordem: botão único de salvar
    if (widget.editOrderOnly) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePrediction,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar Ordem'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 1)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Voltar'),
                ),
              ),
            if (_currentStep > 1) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _onNextPressed,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_currentStep == 3 ? Icons.send : Icons.arrow_forward),
                label: Text(_isSaving ? 'Aguarde...' : _currentStep == 1 ? 'Próximo' : _currentStep == 2 ? 'Salvar Palpite' : 'Enviar para Ligas'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNextPressed() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        _showAuthRequiredDialog();
      } else {
        _savePrediction();
      }
    } else {
      _applyToLeagues();
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entre para salvar'),
        content: const Text(
          'Para salvar seu palpite e aplicá-lo em ligas, você precisa ter uma conta.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/register');
            },
            child: const Text('Fazer Cadastro'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('Fazer Login'),
          ),
        ],
      ),
    );
  }

  String _lockTypeLabel(String type) {
    switch (type) {
      case 'fp1': return 'Antes do TL1';
      case 'qualifying': return 'Antes da Classificação';
      default: return 'Antes da Corrida';
    }
  }

  int _lockTypePoints(String type) {
    switch (type) {
      case 'fp1': return 20;
      case 'qualifying': return 15;
      default: return 10;
    }
  }

  Widget _buildDriverPhoto(dynamic driver, Color teamColor) {
    final photoUrl = driver['photo_url'] as String?;
    final initials = '${(driver['first_name'] as String? ?? ' ')[0]}${(driver['last_name'] as String? ?? ' ')[0]}';

    final fallback = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: teamColor, width: 1.5),
      ),
      child: Center(
        child: Text(initials, style: TextStyle(color: teamColor, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        placeholder: (ctx, url) => fallback,
        errorWidget: (ctx, url, err) => fallback,
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ── Botão de Ordenação Rápida ─────────────────────────────────────────────────
class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap; // null = desabilitado

  const _QuickBtn(this.label, this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.surfaceColor
              : AppTheme.surfaceColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? AppTheme.primaryRed.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: enabled ? AppTheme.primaryRed : Colors.white24,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? Colors.white70 : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
