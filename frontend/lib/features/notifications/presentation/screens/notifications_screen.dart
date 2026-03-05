import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Tela de notificações do usuário
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final res = await _api.get('/notifications');
    if (mounted) {
      setState(() {
        _notifications = res.success && res.data != null
            ? (res.data['notifications'] as List? ?? [])
            : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _api.put('/notifications/read-all');
    setState(() {
      for (final n in _notifications) {
        (n as Map<String, dynamic>)['isRead'] = true;
      }
    });
  }

  Future<void> _markRead(String id, int index) async {
    if (_notifications[index]['isRead'] == true) return;
    await _api.put('/notifications/$id/read');
    if (mounted) {
      setState(() => (_notifications[index] as Map<String, dynamic>)['isRead'] = true);
    }
  }

  /// Navega para a tela correta ao tocar em uma notificação
  Future<void> _onTapNotification(Map<String, dynamic> notif, int index) async {
    final id = notif['id'] as String;
    final type = notif['type'] as String? ?? '';
    final data = (notif['data'] as Map?)?.cast<String, dynamic>() ?? {};

    await _markRead(id, index);
    if (!mounted) return;

    switch (type) {
      case 'new_message':
        final senderId = data['senderId'] as String?;
        if (senderId != null) {
          context.push('/messaging?friendId=$senderId');
        } else {
          context.push('/messaging');
        }
        break;
      case 'league_message':
        final leagueId = data['leagueId'] as String?;
        if (leagueId != null) {
          context.push('/leagues/$leagueId/chat');
        }
        break;
      case 'friend_request':
      case 'friend_accepted':
        final senderId = data['senderId'] as String?;
        if (senderId != null) {
          context.push('/users/$senderId');
        }
        break;
    }
  }

  bool _isNavigable(String type) => const [
    'new_message',
    'league_message',
    'friend_request',
    'friend_accepted',
  ].contains(type);

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isRead'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Marcar todas como lidas'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('Nenhuma notificação.', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final notif = _notifications[i] as Map<String, dynamic>;
                        final isRead = notif['isRead'] == true;
                        final type = notif['type'] as String? ?? '';
                        final title = notif['title'] as String? ?? '';
                        final body = notif['body'] as String? ?? '';
                        final isNavigable = _isNavigable(type);

                        return InkWell(
                          onTap: () => _onTapNotification(notif, i),
                          child: Container(
                            color: isRead ? null : AppTheme.primaryRed.withValues(alpha: 0.06),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForType(type),
                                    color: AppTheme.primaryRed,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(title,
                                                style: TextStyle(
                                                    fontWeight: isRead
                                                        ? FontWeight.normal
                                                        : FontWeight.bold,
                                                    fontSize: 14)),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                  color: AppTheme.primaryRed,
                                                  shape: BoxShape.circle),
                                            ),
                                          if (isNavigable)
                                            const Icon(Icons.chevron_right,
                                                color: AppTheme.textSecondary, size: 16),
                                        ],
                                      ),
                                      if (body.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(body,
                                            style: const TextStyle(
                                                color: AppTheme.textSecondary, fontSize: 13)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'friend_accepted':
        return Icons.people;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'league_message':
        return Icons.groups_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
