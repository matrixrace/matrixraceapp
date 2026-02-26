import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

/// Tela Admin — Gerenciar Corridas (editar datas, status)
class AdminRacesScreen extends StatefulWidget {
  const AdminRacesScreen({super.key});

  @override
  State<AdminRacesScreen> createState() => _AdminRacesScreenState();
}

class _AdminRacesScreenState extends State<AdminRacesScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _races = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/admin/races');
    if (mounted) {
      setState(() {
        _races = (res.data as List?) ?? [];
        _loading = false;
      });
    }
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
                          Text('Corridas', style: Theme.of(context).textTheme.headlineMedium),
                          Text('${_races.length} corridas cadastradas',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _races.map((r) => _buildRaceCard(r)).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildRaceCard(dynamic race) {
    final isCompleted = race['is_completed'] == true;
    final raceDate = DateTime.tryParse(race['race_date'] ?? '');
    final fp1Date = DateTime.tryParse(race['fp1_date'] ?? '');
    final qualiDate = DateTime.tryParse(race['qualifying_date'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted
              ? AppTheme.successGreen.withValues(alpha: 0.15)
              : AppTheme.primaryRed.withValues(alpha: 0.15),
          child: Text(
            '${race['round']}',
            style: TextStyle(
              color: isCompleted ? AppTheme.successGreen : AppTheme.primaryRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(race['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${race['location'] ?? ''} — ${_fmt(raceDate)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.successGreen.withValues(alpha: 0.15)
                    : AppTheme.warningOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCompleted ? 'Concluída' : 'Ativa',
                style: TextStyle(
                  color: isCompleted ? AppTheme.successGreen : AppTheme.warningOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _dateRow('FP1', fp1Date),
                _dateRow('Qualificação', qualiDate),
                _dateRow('Corrida', raceDate),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditModal(race),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar Datas'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryRed),
                          foregroundColor: AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCompleted ? null : () => _markCompleted(race),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Concluir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          disabledBackgroundColor: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, DateTime? date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Text(
            _fmt(date),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _markCompleted(dynamic race) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Marcar como Concluída'),
        content: Text('Confirmar que "${race['name']}" foi concluída?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _api.put('/admin/races/${race['id']}', body: {'isCompleted': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Corrida marcada como concluída!' : 'Erro: ${res.message}'),
          backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
      if (res.success) _load();
    }
  }

  Future<void> _showEditModal(dynamic race) async {
    final fp1Ctrl = TextEditingController(text: race['fp1_date']?.toString().substring(0, 10) ?? '');
    final qualiCtrl = TextEditingController(text: race['qualifying_date']?.toString().substring(0, 10) ?? '');
    final raceDateCtrl = TextEditingController(text: race['race_date']?.toString().substring(0, 10) ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('Editar: ${race['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dateField('Data FP1 (AAAA-MM-DD)', fp1Ctrl),
              const SizedBox(height: 12),
              _dateField('Data Quali (AAAA-MM-DD)', qualiCtrl),
              const SizedBox(height: 12),
              _dateField('Data Corrida (AAAA-MM-DD)', raceDateCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final body = <String, dynamic>{};
              if (fp1Ctrl.text.isNotEmpty) body['fp1Date'] = fp1Ctrl.text;
              if (qualiCtrl.text.isNotEmpty) body['qualifyingDate'] = qualiCtrl.text;
              if (raceDateCtrl.text.isNotEmpty) body['raceDate'] = raceDateCtrl.text;
              final res = await _api.put('/admin/races/${race['id']}', body: body);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.success ? 'Corrida atualizada!' : 'Erro: ${res.message}'),
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
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 12)),
    );
  }
}
