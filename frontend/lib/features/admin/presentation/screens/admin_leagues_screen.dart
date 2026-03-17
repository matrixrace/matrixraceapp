import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/services/feedback_service.dart';

/// Tela Admin — Gerenciar Ligas Oficiais
class AdminLeaguesScreen extends StatefulWidget {
  const AdminLeaguesScreen({super.key});

  @override
  State<AdminLeaguesScreen> createState() => _AdminLeaguesScreenState();
}

class _AdminLeaguesScreenState extends State<AdminLeaguesScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _leagues = [];
  bool _loading = true;
  bool _seeding = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _seedLeagues() async {
    setState(() => _seeding = true);
    final res = await _api.post('/admin/leagues/seed');
    if (mounted) {
      setState(() => _seeding = false);
      if (res.success) {
        FeedbackService.success(context, res.message);
        _load();
      } else {
        FeedbackService.error(context, 'Erro: ${res.message}');
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/admin/leagues');
    if (mounted) {
      setState(() {
        _leagues = (res.data as List?) ?? [];
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _leagues;
    final q = _search.toLowerCase();
    return _leagues.where((l) {
      final name = (l['name'] ?? '').toString().toLowerCase();
      final code = (l['invite_code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    FeedbackService.success(context, 'Código "$code" copiado!');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ShimmerList(itemCount: 6, itemHeight: 72, padding: EdgeInsets.all(24));
    }

    return Column(
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
                    Text('Ligas Oficiais', style: Theme.of(context).textTheme.headlineMedium),
                    Text('${_leagues.length} ligas oficiais',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (_seeding)
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: _seedLeagues,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Criar Ligas Oficiais'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
                ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nome ou código...',
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filtered.isEmpty
              ? EmptyStateWidget(
                  icon: _search.isNotEmpty ? Icons.search_off : Icons.emoji_events_outlined,
                  title: _search.isNotEmpty ? 'Nenhuma liga encontrada' : 'Nenhuma liga oficial',
                  subtitle: _search.isNotEmpty
                      ? 'Tente outro termo de busca.'
                      : 'Clique em "Criar Ligas Oficiais" para gerar automaticamente.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    return _buildLeagueCard(_filtered[i])
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (i * 40).ms);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeagueCard(dynamic league) {
    final inviteCode = league['invite_code'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: InkWell(
          onTap: inviteCode.isNotEmpty ? () => _copyInviteCode(inviteCode) : null,
          borderRadius: BorderRadius.circular(6),
          child: Tooltip(
            message: 'Copiar código',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inviteCode,
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, size: 12, color: AppTheme.primaryRed),
                ],
              ),
            ),
          ),
        ),
        title: Text(league['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${league['member_count'] ?? 0} membros  •  GP: ${league['race_name'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () => _showEditModal(league),
          tooltip: 'Editar',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic league) async {
    final nameCtrl = TextEditingController(text: league['name'] ?? '');
    final descCtrl = TextEditingController(text: league['description'] ?? '');
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 600 ? screenWidth * 0.9 : 420.0;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('Editar: ${league['name']}'),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome da Liga'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _api.put('/admin/leagues/${league['id']}', body: {
                'name': nameCtrl.text,
                'description': descCtrl.text,
              });
              if (mounted) {
                if (res.success) {
                  FeedbackService.success(context, 'Liga atualizada!');
                  _load();
                } else {
                  FeedbackService.error(context, 'Erro: ${res.message}');
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
