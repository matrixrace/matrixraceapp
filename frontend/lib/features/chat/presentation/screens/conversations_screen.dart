import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de lista de conversas privadas
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final res = await _api.get('/messages/conversations');
    if (mounted) {
      setState(() {
        _conversations = res.success && res.data != null ? res.data as List : [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Adicionar amigos',
            onPressed: () => context.push('/friends'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: _conversations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('Nenhuma conversa ainda.',
                              style: TextStyle(color: AppTheme.textSecondary)),
                          SizedBox(height: 4),
                          Text('Adicione amigos para começar a conversar!',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, i) {
                        final conv = _conversations[i];
                        final friend = conv['friend'] as Map<String, dynamic>;
                        final lastMsg = conv['lastMessage'] as Map<String, dynamic>?;
                        final unread = conv['unreadCount'] as int? ?? 0;
                        final name = friend['displayName'] ?? 'Usuário';
                        final avatar = friend['avatarUrl'] as String?;
                        final friendId = friend['id'] as String;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.surfaceColor,
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? Text(name[0].toUpperCase(),
                                    style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: lastMsg != null
                              ? Text(
                                  lastMsg['isFromMe'] == true
                                      ? 'Você: ${lastMsg['content']}'
                                      : lastMsg['content'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                )
                              : null,
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : null,
                          onTap: () => context.push('/chat/$friendId'),
                        );
                      },
                    ),
            ),
    );
  }
}
