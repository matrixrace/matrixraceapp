import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de chat privado em tempo real com um amigo
class ChatScreen extends StatefulWidget {
  final String friendId;

  const ChatScreen({super.key, required this.friendId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  io.Socket? _socket;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _friendData;
  String? _myUserId;
  bool _isLoading = true;
  bool _isSending = false;

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
    // Pega ID do usuário logado
    _myUserId = FirebaseAuth.instance.currentUser?.uid;

    // Carrega dados do amigo
    final friendRes = await _api.get('/users/${widget.friendId}');
    if (mounted && friendRes.success) {
      _friendData = friendRes.data as Map<String, dynamic>?;
    }

    // Carrega histórico de mensagens
    await _loadHistory();

    // Conecta ao Socket.io
    _connectSocket();
  }

  Future<void> _loadHistory() async {
    final res = await _api.get('/messages/private/${widget.friendId}');
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

  void _connectSocket() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;

    // URL base sem o /api/v1
    final socketUrl = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');

    _socket = io.io(socketUrl, {
      'transports': ['websocket'],
      'auth': {'userId': FirebaseAuth.instance.currentUser?.uid},
    });

    _socket!.onConnect((_) {
      // Não precisa fazer nada especial aqui para chat privado
    });

    // Recebe nova mensagem em tempo real
    _socket!.on('new_message', (data) {
      if (!mounted) return;
      final msg = data as Map<String, dynamic>;
      // Apenas adiciona se a mensagem é desta conversa
      final senderId = msg['sender_id'] ?? msg['senderId'];
      if (senderId == widget.friendId) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });

    // Confirma que a mensagem foi enviada
    _socket!.on('message_sent', (data) {
      if (!mounted) return;
      final msg = data as Map<String, dynamic>;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });

    _socket!.on('error', (data) {
      if (!mounted) return;
      final msg = data['message'] ?? 'Erro ao enviar mensagem';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _isSending = false);
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    _socket?.emit('send_message', {
      'receiverId': widget.friendId,
      'content': content,
    });

    setState(() => _isSending = false);
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

  @override
  Widget build(BuildContext context) {
    final friendName = _friendData?['displayName'] ?? 'Amigo';
    final friendAvatar = _friendData?['avatarUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 36,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: friendAvatar != null ? NetworkImage(friendAvatar) : null,
              child: friendAvatar == null
                  ? Text(friendName[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryRed, fontSize: 14, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Text(friendName),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Envie a primeira mensagem!',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
                      ),
          ),

          // Campo de digitação
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'] ?? msg['senderId'];
    final sender = msg['sender'] as Map<String, dynamic>?;
    final senderFirebaseUid = sender?['firebaseUid'] ?? senderId;
    final isMe = senderId == _myUserId || senderFirebaseUid == _myUserId || senderId == (msg['sender']?['id']);

    // Verifica pelo ID do usuário logado
    final content = msg['content'] as String? ?? '';
    final createdAt = msg['created_at'] ?? msg['createdAt'];
    String timeStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt.toString());
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryRed.withValues(alpha: 0.85) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(content,
                style: TextStyle(
                    color: isMe ? Colors.black : AppTheme.textPrimary,
                    fontSize: 15)),
            const SizedBox(height: 3),
            Text(timeStr,
                style: TextStyle(
                    color: isMe ? Colors.black54 : AppTheme.textSecondary,
                    fontSize: 10)),
          ],
        ),
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
                hintText: 'Digite uma mensagem...',
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
              textInputAction: TextInputAction.send,
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
