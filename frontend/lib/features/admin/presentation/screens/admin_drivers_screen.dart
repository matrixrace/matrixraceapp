import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela Admin — Gerenciar Pilotos
class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _drivers = [];
  List<dynamic> _teams = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dRes = await _api.get('/admin/drivers');
    final tRes = await _api.get('/admin/teams');
    if (mounted) {
      setState(() {
        _drivers = (dRes.data as List?) ?? [];
        _teams = (tRes.data as List?) ?? [];
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _drivers;
    final q = _search.toLowerCase();
    return _drivers.where((d) {
      final name = '${d['first_name']} ${d['last_name']}'.toLowerCase();
      return name.contains(q) || '${d['number']}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilotos', style: Theme.of(context).textTheme.headlineMedium),
                          Text('${_drivers.length} pilotos cadastrados',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome ou número...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _filtered.map((d) => _buildDriverCard(d)).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildDriverCard(dynamic d) {
    final isActive = d['is_active'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceColor,
          child: Text(
            '${d['number'] ?? '?'}',
            style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text('${d['first_name'] ?? ''} ${d['last_name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(d['team_name'] ?? 'Sem equipe', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isActive ? 'Ativo' : 'Inativo',
                style: TextStyle(
                  color: isActive ? AppTheme.successGreen : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showEditModal(d),
              tooltip: 'Editar',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic driver) async {
    final firstCtrl = TextEditingController(text: driver['first_name'] ?? '');
    final lastCtrl = TextEditingController(text: driver['last_name'] ?? '');
    final numCtrl = TextEditingController(text: '${driver['number'] ?? ''}');
    String? selectedTeamId = driver['team_id']?.toString();
    bool isActive = driver['is_active'] == true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Text('Editar: ${driver['first_name']} ${driver['last_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lastCtrl,
                  decoration: const InputDecoration(labelText: 'Sobrenome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: 'Número'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedTeamId,
                  decoration: const InputDecoration(labelText: 'Equipe'),
                  dropdownColor: AppTheme.surfaceColor,
                  items: _teams.map<DropdownMenuItem<String>>((t) {
                    return DropdownMenuItem<String>(
                      value: t['id'].toString(),
                      child: Text(t['name'] ?? '', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) => setDlg(() => selectedTeamId = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Ativo', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      activeThumbColor: AppTheme.primaryRed,
                      onChanged: (v) => setDlg(() => isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final body = <String, dynamic>{
                  'firstName': firstCtrl.text,
                  'lastName': lastCtrl.text,
                  'number': int.tryParse(numCtrl.text) ?? driver['number'],
                  'teamId': selectedTeamId,
                  'isActive': isActive,
                };
                final res = await _api.put('/admin/drivers/${driver['id']}', body: body);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.success ? 'Piloto atualizado!' : 'Erro: ${res.message}'),
                      backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
                    ),
                  );
                  if (res.success) _load();
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
