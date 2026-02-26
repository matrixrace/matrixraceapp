import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela de Criação de Liga
/// O usuário preenche nome, tipo (pública/privada), aprovação, limite de membros e corridas
class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMembersController = TextEditingController();

  bool _isPublic = true;
  bool _requiresApproval = false; // só editável em ligas públicas
  bool _limitMembers = false;
  bool _isLoading = false;
  bool _loadingRaces = true;

  List<dynamic> _races = [];
  final Set<int> _selectedRaceIds = {};

  @override
  void initState() {
    super.initState();
    _loadRaces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _loadRaces() async {
    final res = await _api.get('/races/upcoming');
    if (mounted) {
      setState(() {
        _races = (res.success && res.data != null) ? res.data as List : [];
        _loadingRaces = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRaceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma corrida para a liga.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Liga privada sempre exige aprovação (o backend também garante isso)
    final requiresApproval = _isPublic ? _requiresApproval : true;

    // Não incluir campos null — Zod rejeita null em campos .optional()
    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'isPublic': _isPublic,
      'requiresApproval': requiresApproval,
      'raceIds': _selectedRaceIds.toList(),
    };

    final desc = _descriptionController.text.trim();
    if (desc.isNotEmpty) body['description'] = desc;

    if (_limitMembers && _maxMembersController.text.isNotEmpty) {
      body['maxMembers'] = int.parse(_maxMembersController.text);
    }

    final res = await _api.post('/leagues', body: body);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liga criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/leagues');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Liga'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leagues'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da Liga *',
                hintText: 'Ex: Turma do Trabalho F1',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o nome da liga';
                if (v.trim().length < 3) return 'Nome deve ter ao menos 3 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Descreva sua liga...',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 24),

            // Tipo da liga
            Text('Visibilidade', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTypeCard(
                  isSelected: _isPublic,
                  icon: Icons.public,
                  title: 'Pública',
                  subtitle: 'Aparece na lista de ligas',
                  onTap: () => setState(() => _isPublic = true),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildTypeCard(
                  isSelected: !_isPublic,
                  icon: Icons.lock_outline,
                  title: 'Privada',
                  subtitle: 'Só por código de convite',
                  onTap: () => setState(() {
                    _isPublic = false;
                    _requiresApproval = false; // reset, privada sempre tem aprovação
                  }),
                )),
              ],
            ),

            const SizedBox(height: 16),

            // Aprovação — comportamento varia por tipo
            if (_isPublic) ...[
              // Liga pública: o líder escolhe se quer aprovação
              _buildInfoCard(
                icon: Icons.how_to_reg_outlined,
                title: 'Exigir aprovação para entrar',
                subtitle: _requiresApproval
                    ? 'Você precisará aprovar cada novo membro manualmente.'
                    : 'Qualquer pessoa pode entrar automaticamente.',
                trailing: Switch(
                  value: _requiresApproval,
                  activeThumbColor: AppTheme.primaryRed,
                  onChanged: (v) => setState(() => _requiresApproval = v),
                ),
              ),
            ] else ...[
              // Liga privada: aprovação sempre ativa, informativo
              _buildInfoBanner(
                color: Colors.orange,
                icon: Icons.info_outline,
                text:
                    'Liga privada não aparece na lista pública. Apenas quem tiver o código '
                    'de convite pode solicitar entrada, e você precisará aprovar cada membro.',
              ),
            ],

            const SizedBox(height: 24),

            // Limite de membros
            _buildInfoCard(
              icon: Icons.people_outline,
              title: 'Limitar participantes',
              subtitle: _limitMembers
                  ? 'A liga terá um número máximo de membros.'
                  : 'Sem limite de participantes.',
              trailing: Switch(
                value: _limitMembers,
                activeThumbColor: AppTheme.primaryRed,
                onChanged: (v) => setState(() => _limitMembers = v),
              ),
            ),

            if (_limitMembers) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _maxMembersController,
                decoration: const InputDecoration(
                  labelText: 'Máximo de participantes',
                  hintText: 'Ex: 10',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (!_limitMembers) return null;
                  if (v == null || v.isEmpty) return 'Informe o máximo de participantes';
                  final n = int.tryParse(v);
                  if (n == null || n < 2) return 'Mínimo de 2 participantes';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // Corridas
            Text('Corridas da Liga *', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Selecione uma ou mais corridas que farão parte da liga.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _loadingRaces
                ? const Center(child: CircularProgressIndicator())
                : _races.isEmpty
                    ? const Text(
                        'Nenhuma corrida disponível no momento.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      )
                    : Column(
                        children: _races.map((race) {
                          final id = race['id'] as int;
                          final selected = _selectedRaceIds.contains(id);
                          final raceDate = DateTime.tryParse(
                            race['race_date'] ?? race['raceDate'] ?? '',
                          );
                          final dateStr = raceDate != null
                              ? '${raceDate.day.toString().padLeft(2, '0')}/'
                                '${raceDate.month.toString().padLeft(2, '0')}/'
                                '${raceDate.year}'
                              : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: selected
                                    ? AppTheme.primaryRed
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: selected,
                              activeColor: AppTheme.primaryRed,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedRaceIds.add(id);
                                  } else {
                                    _selectedRaceIds.remove(id);
                                  }
                                });
                              },
                              title: Text(
                                race['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Round ${race['round']} · '
                                '${race['location'] ?? ''} · $dateStr',
                                style: const TextStyle(fontSize: 12),
                              ),
                              secondary: CircleAvatar(
                                backgroundColor: selected
                                    ? AppTheme.primaryRed
                                    : AppTheme.surfaceColor,
                                child: Text(
                                  '${race['round']}',
                                  style: TextStyle(
                                    color: selected ? Colors.white : AppTheme.primaryRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 32),

            // Botão criar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.flag),
                label: Text(_isLoading ? 'Criando...' : 'Criar Liga'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Card de tipo de liga (Pública / Privada)
  Widget _buildTypeCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryRed.withValues(alpha: 0.12)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : AppTheme.surfaceColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryRed : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Linha de configuração com ícone, título, subtítulo e um widget à direita (Switch)
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  /// Banner informativo colorido
  Widget _buildInfoBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
