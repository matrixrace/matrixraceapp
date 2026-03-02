import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela admin: gerencia limites globais de ligas e lista usuários
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiClient _api = ApiClient();

  final _joinCtrl = TextEditingController();
  final _createCtrl = TextEditingController();

  List<dynamic> _users = [];
  bool _loadingSettings = true;
  bool _loadingUsers = true;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUsers();
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    _createCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final res = await _api.get('/admin/settings');
    if (mounted && res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      _joinCtrl.text = data['max_leagues_join'] ?? '10';
      _createCtrl.text = data['max_leagues_create'] ?? '3';
      setState(() => _loadingSettings = false);
    } else if (mounted) {
      _joinCtrl.text = '10';
      _createCtrl.text = '3';
      setState(() => _loadingSettings = false);
    }
  }

  Future<void> _loadUsers() async {
    final res = await _api.get('/admin/users');
    if (mounted) {
      setState(() {
        if (res.success && res.data != null) {
          _users = res.data as List;
        }
        _loadingUsers = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final joinVal = int.tryParse(_joinCtrl.text.trim());
    final createVal = int.tryParse(_createCtrl.text.trim());

    if (joinVal == null || createVal == null || joinVal < 1 || createVal < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe valores numéricos válidos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _savingSettings = true);

    await Future.wait([
      _api.put('/admin/settings', body: {'key': 'max_leagues_join', 'value': '$joinVal'}),
      _api.put('/admin/settings', body: {'key': 'max_leagues_create', 'value': '$createVal'}),
    ]);

    if (mounted) {
      setState(() => _savingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limites atualizados!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usuários', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Limites globais e lista de usuários',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

          // ── Limites ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limites globais de ligas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                if (_loadingSettings)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _joinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Máx. ligas que pode entrar',
                            prefixIcon: Icon(Icons.login),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _createCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Máx. ligas que pode criar',
                            prefixIcon: Icon(Icons.add_circle_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savingSettings ? null : _saveSettings,
                      icon: _savingSettings
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(_savingSettings ? 'Salvando...' : 'Salvar Limites'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Lista de usuários ─────────────────────────────────
          Text('Lista de Usuários',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          if (_loadingUsers)
            const Center(child: CircularProgressIndicator())
          else if (_users.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum usuário encontrado.'),
              ),
            )
          else
            ...(_users.map((u) {
              final leagueCount = u['league_count'] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.surfaceColor,
                    child: Text(
                      (u['displayName'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryRed),
                    ),
                  ),
                  title: Text(u['displayName'] ?? ''),
                  subtitle: Text(u['email'] ?? '',
                      style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$leagueCount ligas',
                      style: const TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            })),
        ],
      ),
    );
  }
}
