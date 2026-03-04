const { db } = require('../config/database');
const { pool } = require('../config/database');
const {
  messages,
  users,
  friendships,
  leagueMembers,
  leagues,
  leagueChatAllowed,
  chatGroups,
  chatGroupMembers,
  messageReadReceipts,
} = require('../db/schema');
const { eq, and, or, asc, desc, isNotNull, isNull, sql } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// GET /api/v1/messages/conversations
// Lista unificada de conversas: privadas + grupos + ligas
async function getConversations(req, res, next) {
  try {
    const userId = req.user.id;
    const conversations = [];

    // === CONVERSAS PRIVADAS (otimizado com SQL direto) ===
    const privateResult = await pool.query(`
      WITH ranked AS (
        SELECT
          m.id, m.sender_id, m.receiver_id, m.content, m.is_read, m.created_at,
          CASE WHEN m.sender_id = $1 THEN m.receiver_id ELSE m.sender_id END AS other_id,
          ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN m.sender_id = $1 THEN m.receiver_id ELSE m.sender_id END
            ORDER BY m.created_at DESC
          ) AS rn
        FROM messages m
        WHERE (m.sender_id = $1 OR m.receiver_id = $1)
          AND m.receiver_id IS NOT NULL
          AND m.league_id IS NULL
          AND m.group_id IS NULL
      )
      SELECT r.*, u.display_name, u.avatar_url,
        (SELECT COUNT(*) FROM messages m2
         WHERE m2.sender_id = r.other_id AND m2.receiver_id = $1
           AND m2.is_read = false AND m2.league_id IS NULL AND m2.group_id IS NULL
        ) AS unread_count
      FROM ranked r
      JOIN users u ON u.id = r.other_id
      WHERE r.rn = 1
      ORDER BY r.created_at DESC
    `, [userId]);

    for (const row of privateResult.rows) {
      conversations.push({
        type: 'private',
        friend: {
          id: row.other_id,
          displayName: row.display_name,
          avatarUrl: row.avatar_url,
        },
        lastMessage: {
          content: row.content,
          createdAt: row.created_at,
          isFromMe: row.sender_id === userId,
        },
        unreadCount: parseInt(row.unread_count),
      });
    }

    // === CONVERSAS DE GRUPO ===
    const myGroupMemberships = await db
      .select({ groupId: chatGroupMembers.groupId })
      .from(chatGroupMembers)
      .where(eq(chatGroupMembers.userId, userId));

    for (const { groupId } of myGroupMemberships) {
      const [group] = await db
        .select()
        .from(chatGroups)
        .where(eq(chatGroups.id, groupId))
        .limit(1);

      if (!group) continue;

      const [lastMsg] = await db
        .select({
          content: messages.content,
          createdAt: messages.createdAt,
          senderName: users.displayName,
          senderId: messages.senderId,
        })
        .from(messages)
        .innerJoin(users, eq(messages.senderId, users.id))
        .where(eq(messages.groupId, groupId))
        .orderBy(desc(messages.createdAt))
        .limit(1);

      const [unreadResult] = await db
        .select({ count: sql`COUNT(*)` })
        .from(messages)
        .where(
          and(
            eq(messages.groupId, groupId),
            sql`${messages.senderId} != ${userId}`,
            sql`${messages.id} NOT IN (
              SELECT message_id FROM message_read_receipts
              WHERE user_id = ${userId}
            )`
          )
        );

      const [memberCount] = await db
        .select({ count: sql`COUNT(*)` })
        .from(chatGroupMembers)
        .where(eq(chatGroupMembers.groupId, groupId));

      conversations.push({
        type: 'group',
        group: {
          id: group.id,
          name: group.name,
          avatarUrl: group.avatarUrl,
          memberCount: parseInt(memberCount.count),
        },
        lastMessage: lastMsg
          ? {
              content: lastMsg.content,
              createdAt: lastMsg.createdAt,
              isFromMe: lastMsg.senderId === userId,
              senderName: lastMsg.senderName,
            }
          : null,
        unreadCount: parseInt(unreadResult.count),
      });
    }

    // Ordena tudo por última mensagem (mais recente primeiro)
    conversations.sort((a, b) => {
      const dateA = a.lastMessage?.createdAt || new Date(0);
      const dateB = b.lastMessage?.createdAt || new Date(0);
      return new Date(dateB) - new Date(dateA);
    });

    res.json(successResponse(conversations));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/messages/private/:friendId
// Histórico de mensagens privadas com um amigo (com paginação)
async function getPrivateMessages(req, res, next) {
  try {
    const userId = req.user.id;
    const { friendId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    // Verifica se são amigos
    const [friendship] = await db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.status, 'accepted'),
          or(
            and(eq(friendships.requesterId, userId), eq(friendships.addresseeId, friendId)),
            and(eq(friendships.requesterId, friendId), eq(friendships.addresseeId, userId))
          )
        )
      )
      .limit(1);

    if (!friendship) {
      return next(errorResponse('Vocês não são amigos', 403));
    }

    const history = await db
      .select({
        id: messages.id,
        senderId: messages.senderId,
        content: messages.content,
        isRead: messages.isRead,
        createdAt: messages.createdAt,
      })
      .from(messages)
      .where(
        or(
          and(eq(messages.senderId, userId), eq(messages.receiverId, friendId)),
          and(eq(messages.senderId, friendId), eq(messages.receiverId, userId))
        )
      )
      .orderBy(asc(messages.createdAt))
      .limit(limit)
      .offset(offset);

    // Marca mensagens recebidas como lidas (com readAt)
    await db
      .update(messages)
      .set({ isRead: true, readAt: new Date() })
      .where(
        and(
          eq(messages.senderId, friendId),
          eq(messages.receiverId, userId),
          eq(messages.isRead, false)
        )
      );

    res.json(successResponse(history));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/:id/messages
// Histórico de mensagens do chat da liga
async function getLeagueMessages(req, res, next) {
  try {
    const userId = req.user.id;
    const leagueId = req.params.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    // Verifica se o usuário é membro ativo da liga
    const [member] = await db
      .select()
      .from(leagueMembers)
      .where(
        and(
          eq(leagueMembers.leagueId, leagueId),
          eq(leagueMembers.userId, userId),
          eq(leagueMembers.status, 'active')
        )
      )
      .limit(1);

    if (!member) {
      return next(errorResponse('Você não é membro desta liga', 403));
    }

    const history = await db
      .select({
        id: messages.id,
        senderId: messages.senderId,
        senderName: users.displayName,
        senderAvatar: users.avatarUrl,
        content: messages.content,
        createdAt: messages.createdAt,
      })
      .from(messages)
      .innerJoin(users, eq(messages.senderId, users.id))
      .where(eq(messages.leagueId, leagueId))
      .orderBy(asc(messages.createdAt))
      .limit(limit)
      .offset(offset);

    res.json(successResponse(history));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/leagues/:id/chat-settings
// Altera o modo do chat da liga (apenas o líder pode)
async function updateLeagueChatSettings(req, res, next) {
  try {
    const userId = req.user.id;
    const leagueId = req.params.id;
    const { chatMode } = req.body;

    const validModes = ['all', 'leader_only', 'selected'];
    if (!validModes.includes(chatMode)) {
      return next(errorResponse('Modo de chat inválido. Use: all, leader_only ou selected', 400));
    }

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, leagueId))
      .limit(1);

    if (!league) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    if (league.ownerId !== userId) {
      return next(errorResponse('Apenas o líder da liga pode alterar as configurações do chat', 403));
    }

    const [updated] = await db
      .update(leagues)
      .set({ chatMode, updatedAt: new Date() })
      .where(eq(leagues.id, leagueId))
      .returning();

    res.json(successResponse({ chatMode: updated.chatMode }, 'Configurações do chat atualizadas'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/leagues/:id/chat-allowed/:userId
// Adiciona usuário à lista de permitidos para escrever no chat (modo 'selected')
async function addChatAllowed(req, res, next) {
  try {
    const ownerId = req.user.id;
    const { id: leagueId, userId: targetUserId } = req.params;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, leagueId))
      .limit(1);

    if (!league || league.ownerId !== ownerId) {
      return next(errorResponse('Sem permissão', 403));
    }

    await db
      .insert(leagueChatAllowed)
      .values({ leagueId, userId: targetUserId })
      .onConflictDoNothing();

    res.json(successResponse(null, 'Usuário adicionado à lista de permitidos'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/leagues/:id/chat-allowed/:userId
// Remove usuário da lista de permitidos para escrever no chat
async function removeChatAllowed(req, res, next) {
  try {
    const ownerId = req.user.id;
    const { id: leagueId, userId: targetUserId } = req.params;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, leagueId))
      .limit(1);

    if (!league || league.ownerId !== ownerId) {
      return next(errorResponse('Sem permissão', 403));
    }

    await db
      .delete(leagueChatAllowed)
      .where(
        and(
          eq(leagueChatAllowed.leagueId, leagueId),
          eq(leagueChatAllowed.userId, targetUserId)
        )
      );

    res.json(successResponse(null, 'Usuário removido da lista de permitidos'));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/messages/read
// Marca mensagens específicas como lidas (backup REST para o socket)
async function markAsRead(req, res, next) {
  try {
    const userId = req.user.id;
    const { messageIds } = req.body;

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return next(errorResponse('Informe os IDs das mensagens', 400));
    }

    // Marca mensagens privadas como lidas
    await pool.query(`
      UPDATE messages
      SET is_read = true, read_at = NOW()
      WHERE id = ANY($1) AND receiver_id = $2 AND is_read = false
    `, [messageIds, userId]);

    // Insere read receipts para mensagens de grupo
    for (const msgId of messageIds) {
      await db
        .insert(messageReadReceipts)
        .values({ messageId: msgId, userId })
        .onConflictDoNothing();
    }

    res.json(successResponse(null, 'Mensagens marcadas como lidas'));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getConversations,
  getPrivateMessages,
  getLeagueMessages,
  updateLeagueChatSettings,
  addChatAllowed,
  removeChatAllowed,
  markAsRead,
};
