import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de Amigos
/// Três abas: Amigos | Pedidos recebidos | Buscar pessoas
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Amigos'),
            Tab(text: 'Pedidos'),
            Tab(text: 'Buscar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendListTab(),
          _FriendRequestsTab(),
          _SearchUsersTab(),
        ],
      ),
    );
  }
}

// ── Aba 1: Lista de amigos ────────────────────────────────────────────────────

class _FriendListTab extends StatefulWidget {
  const _FriendListTab();

  @override
  State<_FriendListTab> createState() => _FriendListTabState();
}

class _FriendListTabState extends State<_FriendListTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  List<dynamic> _friends = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final res = await _api.get('/friends');
    if (mounted) {
      setState(() {
        _friends = res.success && res.data != null ? res.data as List : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFriend(String friendshipId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover amigo'),
        content: Text('Deseja remover $name da sua lista de amigos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await _api.delete('/friends/$friendshipId');
    if (mounted && res.success) {
      _loadFriends();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Nenhum amigo ainda.', style: TextStyle(color: AppTheme.textSecondary)),
            SizedBox(height: 4),
            Text('Use a aba "Buscar" para encontrar pessoas!',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _friends.length,
      itemBuilder: (context, i) {
        final friend = _friends[i];
        final name = friend['displayName'] ?? 'Usuário';
        final avatar = friend['avatarUrl'] as String?;
        final friendId = friend['id'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(name[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryRed),
                  tooltip: 'Enviar mensagem',
                  onPressed: () => context.push('/chat/$friendId'),
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: AppTheme.textSecondary),
                  tooltip: 'Remover amigo',
                  onPressed: () => _removeFriend(friendId, name),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Aba 2: Pedidos de amizade recebidos ─────────────────────────────────────

class _FriendRequestsTab extends StatefulWidget {
  const _FriendRequestsTab();

  @override
  State<_FriendRequestsTab> createState() => _FriendRequestsTabState();
}

class _FriendRequestsTabState extends State<_FriendRequestsTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final res = await _api.get('/friends/requests');
    if (mounted) {
      setState(() {
        _requests = res.success && res.data != null ? res.data as List : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _accept(String friendshipId) async {
    final res = await _api.put('/friends/$friendshipId/accept');
    if (mounted && res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido aceito!')),
      );
      _loadRequests();
    }
  }

  Future<void> _decline(String friendshipId) async {
    final res = await _api.delete('/friends/$friendshipId');
    if (mounted && res.success) _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Nenhum pedido pendente.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      itemBuilder: (context, i) {
        final req = _requests[i];
        final user = req['user'] as Map<String, dynamic>;
        final name = user['displayName'] ?? 'Usuário';
        final avatar = user['avatarUrl'] as String?;
        final friendshipId = req['friendshipId'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(name[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('quer ser seu amigo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryRed),
                  tooltip: 'Aceitar',
                  onPressed: () => _accept(friendshipId),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: AppTheme.textSecondary),
                  tooltip: 'Recusar',
                  onPressed: () => _decline(friendshipId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Aba 3: Buscar usuários ────────────────────────────────────────────────────

class _SearchUsersTab extends StatefulWidget {
  const _SearchUsersTab();

  @override
  State<_SearchUsersTab> createState() => _SearchUsersTabState();
}

class _SearchUsersTabState extends State<_SearchUsersTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;
  final Set<String> _pendingRequests = {}; // IDs de quem já enviou pedido

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final res = await _api.get('/users/search?q=${Uri.encodeComponent(query.trim())}');
    if (mounted) {
      setState(() {
        _results = res.success && res.data != null ? res.data as List : [];
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(String userId) async {
    final res = await _api.post('/friends/request/$userId');
    if (mounted) {
      if (res.success) {
        setState(() => _pendingRequests.add(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido de amizade enviado!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nome...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Digite um nome para buscar'
                            : 'Nenhum usuário encontrado',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final user = _results[i];
                        final userId = user['id'] as String;
                        final name = user['displayName'] ?? 'Usuário';
                        final avatar = user['avatarUrl'] as String?;
                        final alreadySent = _pendingRequests.contains(userId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.surfaceColor,
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null
                                  ? Text(name[0].toUpperCase(),
                                      style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: alreadySent
                                ? const Chip(
                                    label: Text('Enviado', style: TextStyle(fontSize: 12)),
                                    backgroundColor: AppTheme.surfaceColor,
                                  )
                                : ElevatedButton(
                                    onPressed: () => _sendRequest(userId),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Adicionar', style: TextStyle(fontSize: 12)),
                                  ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
