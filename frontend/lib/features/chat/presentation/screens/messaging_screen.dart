import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/create_group_dialog.dart';

/// Tela principal de mensagens no estilo WhatsApp Web
/// Split panel: lista de conversas à esquerda, chat à direita
class MessagingScreen extends StatefulWidget {
  final String? initialFriendId;
  final String? initialGroupId;

  const MessagingScreen({
    super.key,
    this.initialFriendId,
    this.initialGroupId,
  });

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final ApiClient _api = ApiClient();
  final SocketService _socketService = SocketService();
  final ScrollController _chatScrollController = ScrollController();

  // Conversas
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoadingConversations = true;
  String _filter = 'all'; // 'all' | 'private' | 'group'

  // Conversa selecionada
  Map<String, dynamic>? _selectedConversation;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = false;

  // Typing
  final Map<String, String> _typingUsers = {}; // usedId -> userName

  // Subscriptions
  StreamSubscription? _newMessageSub;
  StreamSubscription? _messageSentSub;
  StreamSubscription? _newGroupMessageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readReceiptSub;
  StreamSubscription? _onlineStatusSub;

  // Mobile: mostra conversa ou lista
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _newMessageSub?.cancel();
    _messageSentSub?.cancel();
    _newGroupMessageSub?.cancel();
    _typingSub?.cancel();
    _readReceiptSub?.cancel();
    _onlineStatusSub?.cancel();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _socketService.connect();
    _setupListeners();
    await _loadConversations();

    // Se veio com um friendId ou groupId pré-selecionado, seleciona
    if (widget.initialFriendId != null) {
      await _selectPrivateConversation(widget.initialFriendId!);
    } else if (widget.initialGroupId != null) {
      await _selectGroupConversation(widget.initialGroupId!);
    }
  }

  void _setupListeners() {
    _newMessageSub = _socketService.newMessageStream.listen((msg) {
      _handleIncomingPrivateMessage(msg);
    });

    _messageSentSub = _socketService.messageSentStream.listen((msg) {
      _handleSentMessage(msg);
    });

    _newGroupMessageSub = _socketService.newGroupMessageStream.listen((msg) {
      _handleIncomingGroupMessage(msg);
    });

    _typingSub = _socketService.typingStream.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.isTyping) {
          _typingUsers[event.userId] = event.userId;
        } else {
          _typingUsers.remove(event.userId);
        }
      });
    });

    _readReceiptSub = _socketService.readReceiptStream.listen((event) {
      if (!mounted) return;
      setState(() {
        for (final msg in _messages) {
          final msgId = msg['id']?.toString();
          if (msgId != null && event.messageIds.contains(msgId)) {
            msg['isRead'] = true;
            msg['readAt'] = event.readAt;
          }
        }
      });
    });

    _onlineStatusSub = _socketService.onlineUsersStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleIncomingPrivateMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final senderId = msg['sender_id'] ?? msg['senderId'];
    final selectedId = _getSelectedId();

    // Se é da conversa ativa, adiciona e marca como lida
    if (_selectedConversation?['type'] == 'private' && senderId == selectedId) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
      // Marca como lida
      final msgId = msg['id']?.toString();
      if (msgId != null) {
        _socketService.markRead([msgId], senderId: senderId);
      }
    }

    // Atualiza a lista de conversas
    _updateConversationPreview(senderId, msg, 'private');
  }

  void _handleSentMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final receiverId = msg['receiver_id'] ?? msg['receiverId'];
    final selectedId = _getSelectedId();

    if (_selectedConversation?['type'] == 'private' && receiverId == selectedId) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }

    _updateConversationPreview(receiverId, msg, 'private');
  }

  void _handleIncomingGroupMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final groupId = msg['group_id'] ?? msg['groupId'];
    String? selectedGroupId;
    if (_selectedConversation != null && _selectedConversation!['type'] == 'group') {
      final groupData = _selectedConversation!['group'] as Map<String, dynamic>?;
      selectedGroupId = groupData?['id'] as String?;
    }

    if (groupId == selectedGroupId) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
      // Marca como lida
      final msgId = msg['id']?.toString();
      if (msgId != null) {
        _socketService.markRead([msgId]);
      }
    }

    _updateConversationPreview(groupId, msg, 'group');
  }

  void _updateConversationPreview(
      String? otherId, Map<String, dynamic> msg, String type) {
    if (otherId == null) return;
    setState(() {
      // Encontra a conversa existente e atualiza
      bool found = false;
      for (final conv in _conversations) {
        final friendMap = conv['friend'] as Map<String, dynamic>?;
        final groupMap = conv['group'] as Map<String, dynamic>?;
        String? convId;
        if (conv['type'] == 'private') {
          convId = friendMap?['id'] as String?;
        } else {
          convId = groupMap?['id'] as String?;
        }
        if (convId == otherId && conv['type'] == type) {
          conv['lastMessage'] = {
            'content': msg['content'],
            'createdAt': msg['created_at'] ?? msg['createdAt'],
            'isFromMe': msg['sender_id'] == _socketService.myUserId ||
                msg['senderId'] == _socketService.myUserId,
          };
          // Incrementa unread se não é a conversa ativa
          final selectedId = _getSelectedId();
          if (convId != selectedId) {
            conv['unreadCount'] = (conv['unreadCount'] ?? 0) + 1;
          }
          found = true;
          break;
        }
      }

      // Se não encontrou, recarrega a lista
      if (!found) {
        _loadConversations();
      } else {
        // Reordena
        _conversations.sort((a, b) {
          final dateA = a['lastMessage']?['createdAt'];
          final dateB = b['lastMessage']?['createdAt'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return DateTime.parse(dateB.toString())
              .compareTo(DateTime.parse(dateA.toString()));
        });
      }
    });
  }

  String? _getSelectedId() {
    if (_selectedConversation == null) return null;
    if (_selectedConversation!['type'] == 'private') {
      return _selectedConversation!['friend']?['id'];
    }
    return _selectedConversation!['group']?['id'];
  }

  Future<void> _loadConversations() async {
    final res = await _api.get('/messages/conversations');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _conversations =
            (res.data as List).map((c) => Map<String, dynamic>.from(c)).toList();
        _isLoadingConversations = false;
      });
    } else {
      setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _selectConversation(Map<String, dynamic> conversation) async {
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
      _isLoadingMessages = true;
      _showChat = true;
      _typingUsers.clear();
      // Zera unread
      conversation['unreadCount'] = 0;
    });

    if (conversation['type'] == 'private') {
      await _loadPrivateMessages(conversation['friend']?['id']);
    } else if (conversation['type'] == 'group') {
      await _loadGroupMessages(conversation['group']?['id']);
    }
  }

  Future<void> _selectPrivateConversation(String friendId) async {
    // Procura na lista
    final existing = _conversations.firstWhere(
      (c) => c['type'] == 'private' && c['friend']?['id'] == friendId,
      orElse: () => <String, dynamic>{},
    );

    if (existing.isNotEmpty) {
      await _selectConversation(existing);
    } else {
      // Busca dados do amigo e cria conversa virtual
      final res = await _api.get('/users/$friendId');
      if (mounted && res.success && res.data != null) {
        final friendData = Map<String, dynamic>.from(res.data);
        final virtualConv = {
          'type': 'private',
          'friend': {
            'id': friendData['id'],
            'displayName': friendData['displayName'],
            'avatarUrl': friendData['avatarUrl'],
          },
          'lastMessage': null,
          'unreadCount': 0,
        };
        setState(() {
          _conversations.insert(0, virtualConv);
        });
        await _selectConversation(virtualConv);
      }
    }
  }

  Future<void> _selectGroupConversation(String groupId) async {
    final existing = _conversations.firstWhere(
      (c) => c['type'] == 'group' && c['group']?['id'] == groupId,
      orElse: () => <String, dynamic>{},
    );

    if (existing.isNotEmpty) {
      await _selectConversation(existing);
    }
  }

  Future<void> _loadPrivateMessages(String? friendId) async {
    if (friendId == null) return;
    final res = await _api.get('/messages/private/$friendId');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _messages =
            (res.data as List).map((m) => Map<String, dynamic>.from(m)).toList();
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadGroupMessages(String? groupId) async {
    if (groupId == null) return;
    _socketService.joinGroup(groupId);
    final res = await _api.get('/chat-groups/$groupId/messages');
    if (mounted && res.success && res.data != null) {
      setState(() {
        _messages =
            (res.data as List).map((m) => Map<String, dynamic>.from(m)).toList();
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isLoadingMessages = false);
    }
  }

  void _sendMessage(String content) {
    if (_selectedConversation == null) return;

    if (_selectedConversation!['type'] == 'private') {
      final friendId = _selectedConversation!['friend']?['id'];
      if (friendId != null) {
        _socketService.sendMessage(receiverId: friendId, content: content);
      }
    } else if (_selectedConversation!['type'] == 'group') {
      final groupId = _selectedConversation!['group']?['id'];
      if (groupId != null) {
        _socketService.sendGroupMessage(groupId: groupId, content: content);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return _buildWideLayout();
        } else {
          return _buildNarrowLayout();
        }
      },
    );
  }

  /// Layout desktop: split panel
  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Painel esquerdo — lista de conversas
          SizedBox(
            width: 340,
            child: _buildConversationPanel(),
          ),
          // Divisor
          Container(width: 1, color: const Color(0x14FFFFFF)),
          // Painel direito — chat
          Expanded(
            child: _selectedConversation != null
                ? _buildChatPanel()
                : _buildEmptyChatPanel(),
          ),
        ],
      ),
    );
  }

  /// Layout mobile: mostra lista OU chat
  Widget _buildNarrowLayout() {
    return Scaffold(
      body: _showChat && _selectedConversation != null
          ? _buildChatPanel(showBackButton: true)
          : _buildConversationPanel(),
    );
  }

  /// Painel de lista de conversas
  Widget _buildConversationPanel() {
    final filtered = _filteredConversations();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
          decoration: const BoxDecoration(
            color: AppTheme.darkBackground,
            border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Mensagens',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.group_add,
                        color: AppTheme.primaryGreen),
                    tooltip: 'Criar grupo',
                    onPressed: _onCreateGroup,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Tabs de filtro
              Row(
                children: [
                  _buildFilterChip('Todas', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Privadas', 'private'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Grupos', 'group'),
                ],
              ),
            ],
          ),
        ),

        // Lista de conversas
        Expanded(
          child: _isLoadingConversations
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: AppTheme.textSecondary, size: 48),
                          const SizedBox(height: 12),
                          const Text('Nenhuma conversa',
                              style: TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _onCreateGroup,
                            icon: const Icon(Icons.group_add, size: 18),
                            label: const Text('Criar grupo'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _buildConversationItem(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredConversations() {
    if (_filter == 'all') return _conversations;
    return _conversations.where((c) => c['type'] == _filter).toList();
  }

  Widget _buildConversationItem(Map<String, dynamic> conv) {
    final type = conv['type'] as String? ?? 'private';
    final selectedId = _getSelectedId();
    String name;
    String? avatarUrl;
    String? friendId;

    if (type == 'private') {
      final friend = conv['friend'] as Map<String, dynamic>?;
      name = friend?['displayName'] ?? 'Amigo';
      avatarUrl = friend?['avatarUrl'] as String?;
      friendId = friend?['id'] as String?;
    } else {
      final group = conv['group'] as Map<String, dynamic>?;
      name = group?['name'] ?? 'Grupo';
      avatarUrl = group?['avatarUrl'] as String?;
    }

    final lastMsg = conv['lastMessage'] as Map<String, dynamic>?;
    final lastContent = lastMsg?['content'] as String?;
    final lastSender = lastMsg?['senderName'] as String?;
    final lastTime = lastMsg?['createdAt'] != null
        ? DateTime.tryParse(lastMsg!['createdAt'].toString())
        : null;

    final convFriend = conv['friend'] as Map<String, dynamic>?;
    final convGroup = conv['group'] as Map<String, dynamic>?;
    String? currentId;
    if (type == 'private') {
      currentId = convFriend?['id'] as String?;
    } else {
      currentId = convGroup?['id'] as String?;
    }
    final isSelected = currentId == selectedId &&
        conv['type'] == _selectedConversation?['type'];

    return ConversationTile(
      type: type,
      name: name,
      avatarUrl: avatarUrl,
      lastMessage: lastContent,
      lastMessageSender: lastSender,
      lastMessageTime: lastTime,
      unreadCount: conv['unreadCount'] ?? 0,
      isOnline: type == 'private' && friendId != null
          ? _socketService.isOnline(friendId)
          : false,
      isSelected: isSelected,
      onTap: () => _selectConversation(conv),
    );
  }

  /// Painel de chat vazio (nenhuma conversa selecionada)
  Widget _buildEmptyChatPanel() {
    return Container(
      color: AppTheme.darkBackground,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, color: AppTheme.textSecondary, size: 64),
            SizedBox(height: 16),
            Text(
              'Selecione uma conversa',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Escolha um amigo ou grupo na lista ao lado',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Painel de chat ativo
  Widget _buildChatPanel({bool showBackButton = false}) {
    final type = _selectedConversation!['type'];
    String name;
    String? avatarUrl;
    String? friendId;
    bool isOnline = false;

    if (type == 'private') {
      final friend = _selectedConversation!['friend'] as Map<String, dynamic>?;
      name = friend?['displayName'] ?? 'Amigo';
      avatarUrl = friend?['avatarUrl'] as String?;
      friendId = friend?['id'] as String?;
      isOnline = friendId != null && _socketService.isOnline(friendId);
    } else {
      final group = _selectedConversation!['group'] as Map<String, dynamic>?;
      name = group?['name'] ?? 'Grupo';
      avatarUrl = group?['avatarUrl'] as String?;
    }

    // Verifica se alguém está digitando nesta conversa
    final isTyping = _typingUsers.isNotEmpty;

    return Container(
      color: AppTheme.darkBackground,
      child: Column(
        children: [
          // Header do chat
          Container(
            padding: EdgeInsets.fromLTRB(
                showBackButton ? 4 : 16, 48, 16, 12),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
            ),
            child: Row(
              children: [
                if (showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.textPrimary),
                    onPressed: () => setState(() => _showChat = false),
                  ),
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.cardBackground,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isTyping
                            ? 'digitando...'
                            : isOnline
                                ? 'online'
                                : type == 'group'
                                    ? '${_selectedConversation!['group']?['memberCount'] ?? ''} membros'
                                    : '',
                        style: TextStyle(
                          color: isTyping
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mensagens
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Envie a primeira mensagem!',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) =>
                            _buildMessageItem(_messages[i]),
                      ),
          ),

          // Typing indicator
          if (isTyping) const TypingIndicator(),

          // Input bar
          ChatInputBar(
            onSend: _sendMessage,
            onTypingStart: () {
              if (_selectedConversation?['type'] == 'private') {
                _socketService.startTyping(
                    receiverId: _selectedConversation!['friend']?['id']);
              } else if (_selectedConversation?['type'] == 'group') {
                _socketService.startTyping(
                    groupId: _selectedConversation!['group']?['id']);
              }
            },
            onTypingStop: () {
              if (_selectedConversation?['type'] == 'private') {
                _socketService.stopTyping(
                    receiverId: _selectedConversation!['friend']?['id']);
              } else if (_selectedConversation?['type'] == 'group') {
                _socketService.stopTyping(
                    groupId: _selectedConversation!['group']?['id']);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'] ?? msg['senderId'];
    final sender = msg['sender'] as Map<String, dynamic>?;
    final isMe = senderId == _socketService.myUserId ||
        sender?['id'] == _socketService.myUserId;

    final content = msg['content'] as String? ?? '';
    final createdAtStr = msg['created_at'] ?? msg['createdAt'];
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr.toString())
        : null;

    final isRead =
        msg['isRead'] == true || msg['is_read'] == true;
    final readAtStr = msg['readAt'] ?? msg['read_at'];
    final readAt =
        readAtStr != null ? DateTime.tryParse(readAtStr.toString()) : null;

    final isGroup = _selectedConversation?['type'] == 'group';
    final senderName =
        msg['senderName'] ?? msg['sender_name'] ?? sender?['displayName'];
    final senderAvatar =
        msg['senderAvatar'] ?? msg['sender_avatar'] ?? sender?['avatarUrl'];

    return MessageBubble(
      content: content,
      createdAt: createdAt,
      isMe: isMe,
      isRead: isRead,
      readAt: readAt,
      senderName: senderName,
      senderAvatar: senderAvatar,
      showSenderInfo: isGroup,
    );
  }

  Future<void> _onCreateGroup() async {
    final result = await CreateGroupDialog.show(context);
    if (result != null && mounted) {
      // Recarrega conversas e seleciona o novo grupo
      await _loadConversations();
      final groupId = result['id'] as String?;
      if (groupId != null) {
        await _selectGroupConversation(groupId);
      }
    }
  }
}
