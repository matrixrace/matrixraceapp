const { db } = require('../config/database');
const { messages, users, friendships, leagueMembers, leagues, leagueChatAllowed } = require('../db/schema');
const { eq, and, or, asc, desc } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// GET /api/v1/messages/conversations
// Lista todas as conversas privadas do usuário (última mensagem de cada)
async function getConversations(req, res, next) {
  try {
    const userId = req.user.id;

    // Busca todas as mensagens onde o usuário é remetente ou destinatário
    const allMessages = await db
      .select({
        id: messages.id,
        senderId: messages.senderId,
        receiverId: messages.receiverId,
        content: messages.content,
        isRead: messages.isRead,
        createdAt: messages.createdAt,
      })
      .from(messages)
      .where(
        and(
          or(eq(messages.senderId, userId), eq(messages.receiverId, userId)),
          // Mensagens privadas apenas (sem leagueId)
        )
      )
      .orderBy(desc(messages.createdAt));

    // Agrupa por conversa (par de usuários)
    const conversationMap = new Map();
    for (const msg of allMessages) {
      if (!msg.receiverId) continue; // Pula mensagens de liga
      const otherId = msg.senderId === userId ? msg.receiverId : msg.senderId;
      if (!conversationMap.has(otherId)) {
        conversationMap.set(otherId, msg);
      }
    }

    // Busca dados dos outros usuários
    const conversations = await Promise.all(
      Array.from(conversationMap.entries()).map(async ([otherId, lastMsg]) => {
        const [otherUser] = await db
          .select({ id: users.id, displayName: users.displayName, avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, otherId))
          .limit(1);

        // Conta mensagens não lidas desta conversa
        const unreadMessages = allMessages.filter(
          m => m.senderId === otherId && m.receiverId === userId && !m.isRead
        );

        return {
          friend: otherUser,
          lastMessage: { content: lastMsg.content, createdAt: lastMsg.createdAt, isFromMe: lastMsg.senderId === userId },
          unreadCount: unreadMessages.length,
        };
      })
    );

    res.json(successResponse(conversations.filter(c => c.friend)));
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

    // Marca mensagens recebidas como lidas
    await db
      .update(messages)
      .set({ isRead: true })
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

module.exports = {
  getConversations,
  getPrivateMessages,
  getLeagueMessages,
  updateLeagueChatSettings,
  addChatAllowed,
  removeChatAllowed,
};
