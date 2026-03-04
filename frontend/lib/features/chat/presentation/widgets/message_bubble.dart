import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Bolha de mensagem reutilizável — chat privado e de grupo
class MessageBubble extends StatelessWidget {
  final String content;
  final DateTime? createdAt;
  final bool isMe;
  final bool isRead;
  final DateTime? readAt;
  final String? senderName; // para grupos
  final String? senderAvatar; // para grupos
  final bool showSenderInfo; // mostra nome/avatar (grupos)

  const MessageBubble({
    super.key,
    required this.content,
    this.createdAt,
    required this.isMe,
    this.isRead = false,
    this.readAt,
    this.senderName,
    this.senderAvatar,
    this.showSenderInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = createdAt != null
        ? '${createdAt!.toLocal().hour.toString().padLeft(2, '0')}:${createdAt!.toLocal().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar do remetente (apenas grupos, mensagens de outros)
          if (showSenderInfo && !isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage:
                  senderAvatar != null ? NetworkImage(senderAvatar!) : null,
              child: senderAvatar == null
                  ? Text(
                      (senderName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          // Bolha
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryGreen.withValues(alpha: 0.85)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight:
                      isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Nome do remetente (grupos)
                  if (showSenderInfo && !isMe && senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName!,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Conteúdo
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.black : AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Horário + check de leitura
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe ? Colors.black54 : AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: (isRead || readAt != null)
                              ? const Color(0xFF34B7F1) // azul WhatsApp
                              : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
