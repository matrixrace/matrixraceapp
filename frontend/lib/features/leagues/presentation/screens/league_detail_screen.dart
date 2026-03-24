import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isJoining = false;

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

  Future<void> _joinLeague() async {
    setState(() => _isJoining = true);

    final res = await _api.post('/leagues/${widget.leagueId}/join');

    if (!mounted) return;
    setState(() => _isJoining = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você entrou na liga!'), backgroundColor: Colors.green),
      );
      // Recarrega para exibir as tabs
      setState(() {
        _isMember = true;
        _isLoading = true;
      });
      await _init();
    } else {
      final msg = res.message.toLowerCase();
      if (msg.contains('limite')) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(child: Text('Limite de ligas atingido')),
              ],
            ),
            content: const Text(
              'Você atingiu o limite de ligas simultâneas e não foi possível entrar nesta liga.\n\n'
              'Quando as corridas de uma liga que você participa forem finalizadas, ela será desativada e você poderá entrar em novas ligas.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
        );
      }
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

  Future<void> _shareLeague() async {
    final league = _league;
    if (league == null) return;

    final inviteCode = league['invite_code'] ?? league['inviteCode'];
    if (inviteCode == null) return;

    final shareUrl = 'https://www.matrixrace.com/join/$inviteCode';
    final leagueName = league['name'] ?? 'Liga';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Entre na liga "$leagueName" no Matrix Race!\n$shareUrl',
        ),
      );
    } catch (_) {
      // Fallback: copia o link para a área de transferência
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copiado!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Widget _buildJoinView() {
    final league = _league;
    if (league == null) return const SizedBox.shrink();

    final isPublic = league['is_public'] == true || league['isPublic'] == true;
    final requiresApproval = league['requires_approval'] == true || league['requiresApproval'] == true;
    final memberCount = league['member_count'] ?? league['memberCount'] ?? 0;
    final description = league['description'] as String?;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPublic ? Icons.groups_outlined : Icons.lock_outline,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              league['name'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$memberCount membros',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            if (isPublic) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isJoining ? null : _joinLeague,
                  icon: _isJoining
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(requiresApproval ? Icons.how_to_reg : Icons.login),
                  label: Text(_isJoining
                      ? 'Aguarde...'
                      : requiresApproval
                          ? 'Solicitar Entrada'
                          : 'Entrar na Liga'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                ),
              ),
              if (requiresApproval) ...[
                const SizedBox(height: 8),
                const Text(
                  'O líder da liga precisará aprovar sua entrada.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Liga privada — peça o código de convite ao líder da liga.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Voltar'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagueName =
        _league?['name'] as String? ?? 'Liga';
    final showAdminBanner = _isAdmin && !_isMember;
    final showTabs = _isMember || _isAdmin;

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
          if (_isMember)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartilhar liga',
              onPressed: _shareLeague,
            ),
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
        bottom: showTabs
            ? TabBar(
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
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : showTabs
              ? Column(
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
                )
              : _buildJoinView(),
      bottomNavigationBar: AppBottomNav(selectedIndex: 1),
    );
  }
}
