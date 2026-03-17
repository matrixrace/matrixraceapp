import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

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
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Ler todas'),
            ),
        ],
      ),
      body: _isLoading
          ? const ShimmerList(itemCount: 6, itemHeight: 72)
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyStateWidget(
                          icon: Icons.notifications_none,
                          title: 'Tudo em dia!',
                          subtitle: 'Você não tem notificações no momento.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final notif = _notifications[i] as Map<String, dynamic>;
                        return _buildNotificationItem(notif, i);
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, int index) {
    final isRead = notif['isRead'] == true;
    final type = notif['type'] as String? ?? '';
    final title = notif['title'] as String? ?? '';
    final body = notif['body'] as String? ?? '';
    final isNavigable = _isNavigable(type);
    final iconData = _iconForType(type);
    final iconColor = _colorForType(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppTheme.borderSubtle : iconColor.withValues(alpha: 0.2),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Barra colorida na esquerda para unread
            if (!isRead)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _onTapNotification(notif, index),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isRead ? 14 : 10,
                      right: 14,
                      top: 14,
                      bottom: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ícone por tipo
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        // Conteúdo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                  fontSize: 14,
                                  color: isRead ? AppTheme.textPrimary : AppTheme.textPrimary,
                                ),
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Indicadores
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: iconColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: iconColor.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            if (isNavigable) ...[
                              if (!isRead) const SizedBox(height: 6),
                              Icon(Icons.chevron_right,
                                  color: AppTheme.textSecondary, size: 18),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 40).ms);
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

  Color _colorForType(String type) {
    switch (type) {
      case 'friend_request':
        return AppTheme.accentCyan;
      case 'friend_accepted':
        return AppTheme.primaryGreen;
      case 'new_message':
        return AppTheme.accentGold;
      case 'league_message':
        return AppTheme.warningOrange;
      default:
        return AppTheme.primaryGreen;
    }
  }
}
