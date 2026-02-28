import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

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

  // Carrega os 3 conjuntos de dados em paralelo
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

      // Verifica se ao menos um falhou
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

  // ── Cabeçalho: dropdown de ano + botões de seção ──────────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Dropdown de ano
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
          // Botões de seção
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

  // ── Conteúdo por aba ──────────────────────────────────────────
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
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
      return Center(
        child: Text(
          'Nenhum resultado disponível para $_selectedYear',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _races.length,
      itemBuilder: (context, index) =>
          _buildRaceCard(_races[index] as Map<String, dynamic>),
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
    Color posColor = AppTheme.textSecondary;
    if (pos == 1) posColor = AppTheme.primaryRed;
    if (pos == 2) posColor = const Color(0xFFC0C0C0);
    if (pos == 3) posColor = const Color(0xFFCD7F32);

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
            child: Text(
              result['position']?.toString() ?? '-',
              style: TextStyle(color: posColor, fontWeight: FontWeight.bold, fontSize: 13),
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

  // ── Aba Pilotos ────────────────────────────────────────────────
  Widget _buildDriverStandings() {
    if (_driverStandings.isEmpty) {
      return Center(
        child: Text(
          'Classificação não disponível para $_selectedYear',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        // Cabeçalho da tabela
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
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
              Color posColor = Colors.white;
              if (pos == 1) posColor = AppTheme.primaryRed;
              if (pos == 2) posColor = const Color(0xFFC0C0C0);
              if (pos == 3) posColor = const Color(0xFFCD7F32);

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
                      child: Text(
                        s['position']?.toString() ?? '-',
                        style: TextStyle(
                            color: posColor,
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
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Aba Construtores ───────────────────────────────────────────
  Widget _buildConstructorStandings() {
    if (_constructorStandings.isEmpty) {
      return Center(
        child: Text(
          'Classificação não disponível para $_selectedYear',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        // Cabeçalho da tabela
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
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
              Color posColor = Colors.white;
              if (pos == 1) posColor = AppTheme.primaryRed;
              if (pos == 2) posColor = const Color(0xFFC0C0C0);
              if (pos == 3) posColor = const Color(0xFFCD7F32);

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
                      child: Text(
                        s['position']?.toString() ?? '-',
                        style: TextStyle(
                            color: posColor,
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
              );
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
