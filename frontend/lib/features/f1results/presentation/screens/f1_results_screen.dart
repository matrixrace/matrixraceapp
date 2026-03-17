import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/tutorial/tutorial_bloc.dart';
import '../../../../core/tutorial/tutorial_step.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/api_error_widget.dart';

/// Tela de Histórico Esportivo de F1
/// Seções: GPs (resultados por corrida), Pilotos (standings), Construtores (standings)
class F1ResultsScreen extends StatefulWidget {
  const F1ResultsScreen({super.key});

  @override
  State<F1ResultsScreen> createState() => _F1ResultsScreenState();
}

class _F1ResultsScreenState extends State<F1ResultsScreen> {
  final ApiClient _api = ApiClient();
  final int _currentYear = DateTime.now().year;

  int _selectedYear = DateTime.now().year;
  int _selectedTab = 0; // 0=GPs  1=Pilotos  2=Construtores

  List<dynamic> _races = [];
  List<dynamic> _driverStandings = [];
  List<dynamic> _constructorStandings = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/f1-results?year=$_selectedYear'),
        _api.get('/f1-results/drivers?year=$_selectedYear'),
        _api.get('/f1-results/constructors?year=$_selectedYear'),
      ]);

      if (!mounted) return;

      final failed = results.where((r) => !r.success).toList();
      if (failed.isNotEmpty && results[0].data == null) {
        setState(() {
          _error = failed.first.message.isNotEmpty
              ? failed.first.message
              : 'Erro ao carregar dados';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _races = results[0].data?['races'] as List<dynamic>? ?? [];
        _driverStandings =
            results[1].data?['standings'] as List<dynamic>? ?? [];
        _constructorStandings =
            results[2].data?['standings'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TutorialBloc>().add(TutorialScreenVisited('f1results'));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro de conexão';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      key: TutorialKeys.f1Tabs,
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isDense: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor: AppTheme.surfaceColor,
                items: [
                  for (int y = _currentYear; y >= 1950; y--)
                    DropdownMenuItem(
                      value: y,
                      child: Text('$y'),
                    ),
                ],
                onChanged: (y) {
                  if (y != null && y != _selectedYear) {
                    setState(() => _selectedYear = y);
                    _loadAll();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SectionButton(
                  label: 'GPs',
                  index: 0,
                  selected: _selectedTab,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                const SizedBox(width: 6),
                _SectionButton(
                  label: 'Pilotos',
                  index: 1,
                  selected: _selectedTab,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
                const SizedBox(width: 6),
                _SectionButton(
                  label: 'Construtores',
                  index: 2,
                  selected: _selectedTab,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const ShimmerList(itemCount: 6, itemHeight: 72);
    }

    if (_error != null) {
      return ApiErrorWidget(
        message: _error!,
        onRetry: _loadAll,
      );
    }

    switch (_selectedTab) {
      case 1:
        return _buildDriverStandings();
      case 2:
        return _buildConstructorStandings();
      default:
        return _buildGPsList();
    }
  }

  // ── Aba GPs ────────────────────────────────────────────────────
  Widget _buildGPsList() {
    if (_races.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.flag_outlined,
        title: 'Nenhum resultado disponível',
        subtitle: 'Dados de $_selectedYear ainda não estão disponíveis.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _races.length,
      itemBuilder: (context, index) =>
          _buildRaceCard(_races[index] as Map<String, dynamic>)
              .animate()
              .fadeIn(duration: 200.ms, delay: (index * 30).ms),
    );
  }

  Widget _buildRaceCard(Map<String, dynamic> race) {
    final results = race['results'] as List<dynamic>? ?? [];
    final formattedDate = _formatDate(race['date'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            race['round']?.toString() ?? '-',
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          race['raceName'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '$formattedDate  ·  ${race['circuit'] ?? ''}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Resultados ainda não disponíveis',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...results.asMap().entries.map(
                (e) => _buildResultRow(e.value as Map<String, dynamic>, e.key)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildResultRow(Map<String, dynamic> result, int index) {
    final pos = int.tryParse(result['position']?.toString() ?? '') ?? 99;

    final status = result['status'] as String? ?? '';
    final isFinished = status == 'Finished' || status.startsWith('+');
    final timeOrStatus = isFinished ? (result['time'] ?? status) : status;

    return Container(
      color: index.isOdd ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: pos <= 3
                ? _podiumBadge(pos)
                : Text(
                    result['position']?.toString() ?? '-',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              result['driverCode']?.toString() ?? '',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
          Expanded(
            child: Text(result['driver']?.toString() ?? '',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 90,
            child: Text(
              result['team']?.toString() ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              timeOrStatus?.toString() ?? '',
              style: TextStyle(
                  color: isFinished ? Colors.white70 : Colors.orange.shade300,
                  fontSize: 11),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _podiumBadge(int pos) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final color = colors[pos]!;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        '$pos',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // ── Aba Pilotos ────────────────────────────────────────────────
  Widget _buildDriverStandings() {
    if (_driverStandings.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_outline,
        title: 'Classificação não disponível',
        subtitle: 'Dados de $_selectedYear ainda não estão disponíveis.',
      );
    }

    return Column(
      children: [
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              SizedBox(width: 32, child: Text('Pos', style: _headerStyle)),
              SizedBox(width: 40, child: Text('Cód', style: _headerStyle)),
              Expanded(child: Text('Piloto', style: _headerStyle)),
              SizedBox(
                  width: 90,
                  child: Text('Equipe', style: _headerStyle, textAlign: TextAlign.right)),
              SizedBox(
                  width: 44,
                  child: Text('Pts', style: _headerStyle, textAlign: TextAlign.right)),
              SizedBox(
                  width: 28,
                  child: Text('V', style: _headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _driverStandings.length,
            itemBuilder: (context, index) {
              final s = _driverStandings[index] as Map<String, dynamic>;
              final pos = int.tryParse(s['position']?.toString() ?? '') ?? 99;

              return Container(
                color: index.isOdd
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.02),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: pos <= 3
                          ? _podiumBadge(pos)
                          : Text(
                              s['position']?.toString() ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        s['driverCode']?.toString() ?? '',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s['driver']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        s['team']?.toString() ?? '',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        s['points']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        s['wins']?.toString() ?? '0',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms, delay: (index * 20).ms);
            },
          ),
        ),
      ],
    );
  }

  // ── Aba Construtores ───────────────────────────────────────────
  Widget _buildConstructorStandings() {
    if (_constructorStandings.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.build_outlined,
        title: 'Classificação não disponível',
        subtitle: 'Dados de $_selectedYear ainda não estão disponíveis.',
      );
    }

    return Column(
      children: [
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              SizedBox(width: 32, child: Text('Pos', style: _headerStyle)),
              Expanded(child: Text('Equipe', style: _headerStyle)),
              SizedBox(
                  width: 44,
                  child: Text('Pts', style: _headerStyle, textAlign: TextAlign.right)),
              SizedBox(
                  width: 28,
                  child: Text('V', style: _headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _constructorStandings.length,
            itemBuilder: (context, index) {
              final s = _constructorStandings[index] as Map<String, dynamic>;
              final pos = int.tryParse(s['position']?.toString() ?? '') ?? 99;

              return Container(
                color: index.isOdd
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.02),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: pos <= 3
                          ? _podiumBadge(pos)
                          : Text(
                              s['position']?.toString() ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                    ),
                    Expanded(
                      child: Text(
                        s['team']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        s['points']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        s['wins']?.toString() ?? '0',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms, delay: (index * 20).ms);
            },
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      const months = [
        '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
      ];
      final month = int.tryParse(parts[1]) ?? 0;
      return '${parts[2]} ${months[month]} ${parts[0]}';
    } catch (_) {
      return dateStr;
    }
  }

  static const TextStyle _headerStyle = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

// ── Botão de seção (GPs / Pilotos / Construtores) ─────────────────────────────
class _SectionButton extends StatelessWidget {
  final String label;
  final int index;
  final int selected;
  final VoidCallback onTap;

  const _SectionButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
