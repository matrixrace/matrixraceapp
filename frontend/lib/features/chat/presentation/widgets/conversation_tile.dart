import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'online_indicator.dart';

/// Tile de conversa na lista lateral (privada, grupo ou liga)
class ConversationTile extends StatelessWidget {
  final String type; // 'private' | 'group' | 'league'
  final String name;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageSender; // para grupos
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline; // apenas para privado
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(lastMessageTime);
    final preview = _buildPreview();

    return Material(
      color: isSelected
          ? AppTheme.primaryGreen.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x0AFFFFFF)),
            ),
          ),
          child: Row(
            children: [
              // Avatar com indicador online
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surfaceColor,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? _buildAvatarFallback()
                        : null,
                  ),
                  if (type == 'private' && isOnline)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: OnlineIndicator(),
                    ),
                  if (type == 'group')
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.darkBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group,
                            size: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Nome + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    IconData icon;
    switch (type) {
      case 'group':
        icon = Icons.group;
        break;
      case 'league':
        icon = Icons.emoji_events;
        break;
      default:
        return Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
    }
    return Icon(icon, color: AppTheme.primaryGreen, size: 22);
  }

  String _buildPreview() {
    if (lastMessage == null || lastMessage!.isEmpty) {
      return 'Nenhuma mensagem';
    }
    if (type == 'group' && lastMessageSender != null) {
      return '$lastMessageSender: $lastMessage';
    }
    return lastMessage!;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0 && local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && local.day != now.day)) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      return days[local.weekday % 7];
    } else {
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    }
  }
}
