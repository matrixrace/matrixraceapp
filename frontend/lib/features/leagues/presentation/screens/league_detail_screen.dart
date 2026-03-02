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

  const LeagueDetailScreen({super.key, required this.leagueId});

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
      _isMember = league['is_member'] == true;
      _canPost = _isOwner || postMode == 'all';

      setState(() {
        _league = league;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
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
        title: Text(leagueName),
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
