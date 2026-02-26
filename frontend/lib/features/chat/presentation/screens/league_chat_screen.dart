import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de chat em grupo de uma liga
/// O líder pode configurar quem pode enviar mensagens
class LeagueChatScreen extends StatefulWidget {
  final String leagueId;
  final String leagueName;

  const LeagueChatScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<LeagueChatScreen> createState() => _LeagueChatScreenState();
}

class _LeagueChatScreenState extends State<LeagueChatScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  io.Socket? _socket;
  List<Map<String, dynamic>> _messages = [];
  String? _myUserId;
  String? _chatMode;
  bool _isOwner = false;
  bool _canWrite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myUserId = FirebaseAuth.instance.currentUser?.uid;

    // Carrega info da liga e permissões
    final leagueRes = await _api.get('/leagues/${widget.leagueId}');
    if (mounted && leagueRes.success && leagueRes.data != null) {
      final league = leagueRes.data as Map<String, dynamic>;
      final meRes = await _api.get('/auth/me');
      if (mounted && meRes.success) {
        final me = meRes.data as Map<String, dynamic>;
        final ownerId = league['owner_id'] ?? league['ownerId'];
        _isOwner = me['id'] == ownerId;
        _chatMode = league['chat_mode'] ?? league['chatMode'] ?? 'all';
        _canWrite = _isOwner || _chatMode == 'all';
      }
    }

    // Carrega histórico
    await _loadHistory();

    // Conecta Socket.io
    _connectSocket();
  }

  Future<void> _loadHistory() async {
    final res = await _api.get('/leagues/${widget.leagueId}/messages');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _messages = (res.data as List).map((m) => m as Map<String, dynamic>).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _connectSocket() {
    final socketUrl = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');

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

    _socket!.on('error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Erro ao enviar mensagem')),
      );
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _socket?.emit('send_league_message', {
      'leagueId': widget.leagueId,
      'content': content,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showChatSettings() async {
    String selectedMode = _chatMode ?? 'all';

    // Captura referências antes do gap assíncrono
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final options = [
            ('all', 'Todos podem escrever', Icons.people),
            ('leader_only', 'Apenas o líder', Icons.admin_panel_settings),
            ('selected', 'Apenas selecionados', Icons.group_add),
          ];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Configurações do Chat',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: selectedMode,
                  onChanged: (v) => setModalState(() => selectedMode = v!),
                  child: Column(
                    children: options
                        .map((opt) => RadioListTile<String>(
                              value: opt.$1,
                              title: Row(children: [
                                Icon(opt.$3, size: 18, color: AppTheme.primaryRed),
                                const SizedBox(width: 8),
                                Text(opt.$2),
                              ]),
                              activeColor: AppTheme.primaryRed,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final res = await _api.put(
                      '/leagues/${widget.leagueId}/chat-settings',
                      body: {'chatMode': selectedMode},
                    );
                    navigator.pop();
                    if (res.success && mounted) {
                      setState(() {
                        _chatMode = selectedMode;
                        _canWrite = _isOwner || selectedMode == 'all';
                      });
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Configurações salvas!')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.leagueName),
            Text(
              _chatModeLabel(),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações do chat',
              onPressed: _showChatSettings,
            ),
        ],
      ),
      body: Column(
        children: [
          // Aviso se não pode escrever
          if (!_canWrite)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppTheme.surfaceColor,
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _chatMode == 'leader_only'
                        ? 'Apenas o líder pode enviar mensagens'
                        : 'Você não tem permissão para escrever aqui',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Nenhuma mensagem ainda.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
                      ),
          ),

          // Input (apenas se pode escrever)
          if (_canWrite) _buildInputBar(),
        ],
      ),
    );
  }

  String _chatModeLabel() {
    switch (_chatMode) {
      case 'leader_only':
        return 'Apenas o líder pode escrever';
      case 'selected':
        return 'Chat restrito';
      default:
        return 'Todos podem participar';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'] ?? msg['senderId'];
    final sender = msg['sender'] as Map<String, dynamic>?;
    final senderName = msg['sender_name'] ?? msg['senderName'] ?? sender?['displayName'] ?? 'Usuário';
    final senderAvatar = msg['sender_avatar'] ?? msg['senderAvatar'] ?? sender?['avatarUrl'];
    final isMe = senderId == _myUserId || sender?['id'] == _myUserId;
    final content = msg['content'] as String? ?? '';

    final createdAt = msg['created_at'] ?? msg['createdAt'];
    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt.toString());
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: senderAvatar != null ? NetworkImage(senderAvatar.toString()) : null,
              child: senderAvatar == null
                  ? Text(senderName[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryRed, fontSize: 10, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryRed.withValues(alpha: 0.85) : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(senderName,
                        style: const TextStyle(
                            color: AppTheme.primaryRed, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(content,
                      style: TextStyle(
                          color: isMe ? Colors.black : AppTheme.textPrimary,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(timeStr,
                      style: TextStyle(
                          color: isMe ? Colors.black54 : AppTheme.textSecondary,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
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
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Mensagem para a liga...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded, color: AppTheme.primaryRed),
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
