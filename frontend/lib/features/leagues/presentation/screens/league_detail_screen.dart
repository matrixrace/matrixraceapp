import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../widgets/mural_tab.dart';
import '../widgets/placar_tab.dart';
import '../widgets/corridas_tab.dart';

/// Tela principal de uma liga com abas: Mural | Placar | Corridas
class LeagueDetailScreen extends StatefulWidget {
  final String leagueId;
  // Hint de membership vindo da tela de listagem (mais confiável que o campo is_member da API)
  final bool? isMemberHint;

  const LeagueDetailScreen({super.key, required this.leagueId, this.isMemberHint});

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();

  late TabController _tabController;

  Map<String, dynamic>? _league;
  String? _myUserId;
  bool _isOwner = false;
  bool _canPost = false;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myUserId = FirebaseAuth.instance.currentUser?.uid;
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      _api.get('/leagues/${widget.leagueId}'),
      _api.get('/auth/me'),
    ]);

    if (!mounted) return;

    final leagueRes = results[0];
    final meRes = results[1];

    if (leagueRes.success && leagueRes.data != null) {
      final league = leagueRes.data as Map<String, dynamic>;
      final me = meRes.success ? meRes.data as Map<String, dynamic> : null;

      final ownerId = league['owner_id'] ?? league['ownerId'];
      final myId = me?['id'];
      final postMode = league['post_mode'] ?? league['postMode'] ?? 'all';

      _isOwner = myId == ownerId;
      _isAdmin = me?['isAdmin'] == true || me?['is_admin'] == true;
      // Usa o hint da listagem (mais confiável) ou o campo da API como fallback
      _isMember = (widget.isMemberHint ?? false) || league['is_member'] == true;
      _canPost = _isOwner || postMode == 'all';

      setState(() {
        _league = league;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveLeague() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da liga'),
        content: Text(
          'Tem certeza que deseja sair de "${_league?['name']}"?\n\nSeu histórico de pontos será mantido, mas você perderá acesso ao mural e placar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await _api.delete('/leagues/${widget.leagueId}/leave');
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você saiu da liga')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showPostSettings() async {
    String selected =
        _league?['post_mode'] ?? _league?['postMode'] ?? 'all';
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Configurações do Mural',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              RadioListTile<String>(
                value: 'all',
                groupValue: selected,
                title: const Text('Todos podem postar'),
                activeColor: AppTheme.primaryRed,
                onChanged: (v) => setModal(() => selected = v!),
              ),
              RadioListTile<String>(
                value: 'leader_only',
                groupValue: selected,
                title: const Text('Apenas o líder pode postar'),
                activeColor: AppTheme.primaryRed,
                onChanged: (v) => setModal(() => selected = v!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final res = await _api.put(
                    '/leagues/${widget.leagueId}/post-settings',
                    body: {'postMode': selected},
                  );
                  navigator.pop();
                  if (res.success && mounted) {
                    setState(() {
                      _league?['post_mode'] = selected;
                      _canPost = _isOwner || selected == 'all';
                    });
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Configurações salvas!')));
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagueName =
        _league?['name'] as String? ?? 'Liga';
    final showAdminBanner = _isAdmin && !_isMember;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(leagueName, overflow: TextOverflow.ellipsis),
            ),
            // Gear para membros não-donos: usa hint da navegação OU _isMember
            if ((_isMember || widget.isMemberHint == true) && !_isOwner) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings_outlined, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'leave') _leaveLeague();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(children: [
                      Icon(Icons.exit_to_app_outlined, size: 18,
                          color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sair da liga',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings_outlined),
              onSelected: (value) {
                if (value == 'mural') _showPostSettings();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'mural',
                    child: Row(children: [
                      Icon(Icons.article_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Config. Mural'),
                    ])),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRed,
          labelColor: AppTheme.primaryRed,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Mural'),
            Tab(text: 'Placar'),
            Tab(text: 'Corridas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner "Visualizando como Admin"
                if (showAdminBanner)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings,
                            size: 14, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(
                          'Visualizando como Admin',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      MuralTab(
                        leagueId: widget.leagueId,
                        myUserId: _myUserId ?? '',
                        isOwner: _isOwner,
                        canPost: _canPost,
                      ),
                      PlacarTab(
                        leagueId: widget.leagueId,
                        myUserId: _myUserId ?? '',
                      ),
                      CorridasTab(leagueId: widget.leagueId),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: AppBottomNav(selectedIndex: 1),
    );
  }
}
