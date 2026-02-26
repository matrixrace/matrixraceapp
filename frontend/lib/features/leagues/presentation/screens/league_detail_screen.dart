import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/mural_tab.dart';
import '../widgets/placar_tab.dart';
import '../widgets/corridas_tab.dart';

/// Tela principal de uma liga com abas: Mural | Placar | Corridas | Chat
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

  // Chat (aba 3)
  io.Socket? _socket;
  List<Map<String, dynamic>> _messages = [];
  String? _chatMode;
  bool _canWrite = false;
  bool _chatLoading = true;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _myUserId = FirebaseAuth.instance.currentUser?.uid;
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _socket?.disconnect();
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 3 && _socket == null) {
      _initChat();
    }
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
      _chatMode = league['chat_mode'] ?? league['chatMode'] ?? 'all';
      _canWrite = _isOwner || _chatMode == 'all';
      _canPost = _isOwner || postMode == 'all';

      setState(() {
        _league = league;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initChat() async {
    // Carrega histórico
    final res =
        await _api.get('/leagues/${widget.leagueId}/messages');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _messages = (res.data as List)
            .map((m) => m as Map<String, dynamic>)
            .toList();
        _chatLoading = false;
      });
      _scrollToBottom();
    } else if (mounted) {
      setState(() => _chatLoading = false);
    }

    // Conecta Socket.io
    final socketUrl =
        AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
    _socket = io.io(socketUrl, {
      'transports': ['websocket'],
      'auth': {'userId': FirebaseAuth.instance.currentUser?.uid},
    });

    _socket!.onConnect((_) {
      _socket!.emit('join_league', {'leagueId': widget.leagueId});
    });

    _socket!.on('new_league_message', (data) {
      if (!mounted) return;
      setState(() => _messages.add(data as Map<String, dynamic>));
      _scrollToBottom();
    });
  }

  void _sendChatMessage() {
    final content = _chatController.text.trim();
    if (content.isEmpty) return;
    _chatController.clear();
    _socket?.emit('send_league_message', {
      'leagueId': widget.leagueId,
      'content': content,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setModal(() => selected = v!),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'all',
                      title: const Text('Todos podem postar'),
                      activeColor: AppTheme.primaryRed,
                    ),
                    RadioListTile<String>(
                      value: 'leader_only',
                      title: const Text('Apenas o líder pode postar'),
                      activeColor: AppTheme.primaryRed,
                    ),
                  ],
                ),
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

  Future<void> _showChatSettings() async {
    String selected = _chatMode ?? 'all';
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
              const Text('Configurações do Chat',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setModal(() => selected = v!),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'all',
                      title: const Text('Todos podem escrever'),
                      activeColor: AppTheme.primaryRed,
                    ),
                    RadioListTile<String>(
                      value: 'leader_only',
                      title: const Text('Apenas o líder'),
                      activeColor: AppTheme.primaryRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final res = await _api.put(
                    '/leagues/${widget.leagueId}/chat-settings',
                    body: {'chatMode': selected},
                  );
                  navigator.pop();
                  if (res.success && mounted) {
                    setState(() {
                      _chatMode = selected;
                      _canWrite = _isOwner || selected == 'all';
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
                if (value == 'chat') _showChatSettings();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'mural',
                    child: Row(children: [
                      Icon(Icons.article_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Config. Mural'),
                    ])),
                const PopupMenuItem(
                    value: 'chat',
                    child: Row(children: [
                      Icon(Icons.chat_bubble_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Config. Chat'),
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
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Aba 1: Mural
                MuralTab(
                  leagueId: widget.leagueId,
                  myUserId: _myUserId ?? '',
                  isOwner: _isOwner,
                  canPost: _canPost,
                ),

                // Aba 2: Placar
                PlacarTab(
                  leagueId: widget.leagueId,
                  myUserId: _myUserId ?? '',
                ),

                // Aba 3: Corridas
                CorridasTab(leagueId: widget.leagueId),

                // Aba 4: Chat
                _buildChatTab(),
              ],
            ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        if (!_canWrite)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _chatMode == 'leader_only'
                      ? 'Apenas o líder pode enviar mensagens'
                      : 'Você não tem permissão para escrever aqui',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(
          child: _chatLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Text('Nenhuma mensagem ainda.',
                          style: TextStyle(
                              color: AppTheme.textSecondary)),
                    )
                  : ListView.builder(
                      controller: _chatScroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) =>
                          _buildBubble(_messages[i]),
                    ),
        ),
        if (_canWrite) _buildChatInput(),
      ],
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'] ?? msg['senderId'];
    final sender = msg['sender'] as Map<String, dynamic>?;
    final senderName = msg['sender_name'] ??
        msg['senderName'] ??
        sender?['displayName'] ??
        'Usuário';
    final senderAvatar =
        msg['sender_avatar'] ?? msg['senderAvatar'] ?? sender?['avatarUrl'];
    final isMe = senderId == _myUserId ||
        sender?['id'] == _myUserId;
    final content = msg['content'] as String? ?? '';
    final createdAt = msg['created_at'] ?? msg['createdAt'];
    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt.toString());
      if (dt != null) {
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: senderAvatar != null
                  ? NetworkImage(senderAvatar.toString())
                  : null,
              child: senderAvatar == null
                  ? Text(senderName[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width * 0.68),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryRed.withValues(alpha: 0.85)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: isMe
                      ? const Radius.circular(14)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(senderName.toString(),
                        style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  Text(content,
                      style: TextStyle(
                          color:
                              isMe ? Colors.black : AppTheme.textPrimary,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(timeStr,
                      style: TextStyle(
                          color: isMe
                              ? Colors.black54
                              : AppTheme.textSecondary,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: 'Mensagem para a liga...',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _sendChatMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendChatMessage,
            icon: const Icon(Icons.send_rounded,
                color: AppTheme.primaryRed),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceColor,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
