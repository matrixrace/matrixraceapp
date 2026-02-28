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
  bool _syncing = false;

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

  Future<void> _syncSchedule() async {
    final year = DateTime.now().year;
    setState(() => _syncing = true);
    final res = await _api.post('/admin/races/sync-schedule?year=$year');
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.success ? res.message : 'Erro: ${res.message}'),
        backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
        duration: const Duration(seconds: 4),
      ));
      if (res.success) _load();
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
                    if (_syncing)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: _syncSchedule,
                        icon: const Icon(Icons.sync, size: 16),
                        label: Text('Sincronizar ${DateTime.now().year}'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
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
    // Drizzle ORM retorna camelCase; pool.query retorna snake_case — suportamos os dois
    final isCompleted = race['isCompleted'] == true || race['is_completed'] == true;
    final raceDate  = _parseUtc(race['raceDate']       ?? race['race_date']);
    final fp1Date   = _parseUtc(race['fp1Date']        ?? race['fp1_date']);
    final qualiDate = _parseUtc(race['qualifyingDate'] ?? race['qualifying_date']);

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
                _dateRow('TL1', fp1Date),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Text(
            _fmt(date),
            style: TextStyle(
              fontSize: 12,
              color: date != null ? Colors.white : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  /// Converte string UTC do backend para DateTime local
  DateTime? _parseUtc(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Formata DateTime (já em horário local) como DD/MM/YYYY HH:MM
  String _fmt(DateTime? dt) {
    if (dt == null) return 'N/A';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
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
    // Inicializa com horário local (já convertido por _parseUtc)
    DateTime? fp1    = _parseUtc(race['fp1Date']        ?? race['fp1_date']);
    DateTime? quali  = _parseUtc(race['qualifyingDate'] ?? race['qualifying_date']);
    DateTime? raceDt = _parseUtc(race['raceDate']       ?? race['race_date']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> pickDateTime(
            DateTime? current,
            void Function(DateTime picked) onPicked,
          ) async {
            final date = await showDatePicker(
              context: ctx,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppTheme.primaryRed),
                ),
                child: child!,
              ),
            );
            if (date == null || !ctx.mounted) return;
            final time = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppTheme.primaryRed),
                ),
                child: child!,
              ),
            );
            if (time == null) return;
            onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
          }

          Widget dtTile(String label, DateTime? val, void Function(DateTime) onPick) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              subtitle: Text(
                val != null ? _fmt(val) : 'Toque para definir',
                style: TextStyle(
                  fontSize: 13,
                  color: val != null ? Colors.white : Colors.white38,
                ),
              ),
              trailing: Icon(
                Icons.edit_calendar,
                size: 18,
                color: val != null ? AppTheme.primaryRed : Colors.white38,
              ),
              onTap: () => pickDateTime(val, (picked) => setModalState(() => onPick(picked))),
            );
          }

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: Text('Editar: ${race['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Horários no seu fuso local',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 8),
                  dtTile('TL1', fp1,   (v) => fp1 = v),
                  const Divider(height: 1),
                  dtTile('Qualificação', quali, (v) => quali = v),
                  const Divider(height: 1),
                  dtTile('Corrida *', raceDt,  (v) => raceDt = v),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: raceDt == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final body = <String, dynamic>{
                          'raceDate': raceDt!.toUtc().toIso8601String(),
                        };
                        if (fp1 != null)  body['fp1Date']        = fp1!.toUtc().toIso8601String();
                        if (quali != null) body['qualifyingDate'] = quali!.toUtc().toIso8601String();
                        final res = await _api.put('/admin/races/${race['id']}', body: body);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res.success ? 'Corrida atualizada!' : 'Erro: ${res.message}'),
                            backgroundColor: res.success ? AppTheme.successGreen : AppTheme.primaryRed,
                          ));
                          if (res.success) _load();
                        }
                      },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
