const { Server } = require('socket.io');
const { db } = require('./database');
const {
  messages,
  friendships,
  leagueMembers,
  leagues,
  leagueChatAllowed,
  users,
  notifications,
  chatGroups,
  chatGroupMembers,
  messageReadReceipts,
} = require('../db/schema');
const { eq, and, or, inArray } = require('drizzle-orm');
const logger = require('../utils/logger');
const admin = require('firebase-admin');

// Mapa: userId (UUID do banco) -> socketId
const onlineUsers = new Map();

// Helper: retorna IDs dos amigos aceitos de um usuário
async function getFriendIds(userId) {
  const friendsAsRequester = await db
    .select({ friendId: friendships.addresseeId })
    .from(friendships)
    .where(and(eq(friendships.requesterId, userId), eq(friendships.status, 'accepted')));

  const friendsAsAddressee = await db
    .select({ friendId: friendships.requesterId })
    .from(friendships)
    .where(and(eq(friendships.addresseeId, userId), eq(friendships.status, 'accepted')));

  return [
    ...friendsAsRequester.map(f => f.friendId),
    ...friendsAsAddressee.map(f => f.friendId),
  ];
}

// Helper: busca userId do banco pelo firebaseUid
async function getUserByFirebaseUid(firebaseUid) {
  const [user] = await db
    .select({ id: users.id })
    .from(users)
    .where(eq(users.firebaseUid, firebaseUid))
    .limit(1);
  return user;
}

function initSocket(httpServer, corsOrigin) {
  const io = new Server(httpServer, {
    cors: {
      origin: corsOrigin,
      methods: ['GET', 'POST'],
      credentials: true,
    },
  });

  // Middleware de autenticação via Firebase token
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      const userId = socket.handshake.auth.userId;

      // Se tem token Firebase, validar e resolver o userId
      if (token) {
        try {
          const decoded = await admin.auth().verifyIdToken(token);
          const user = await getUserByFirebaseUid(decoded.uid);
          if (user) {
            socket.userId = user.id;
            return next();
          }
        } catch (err) {
          logger.warn('Socket: Firebase token inválido, tentando userId direto');
        }
      }

      // Fallback: aceita userId direto (compatibilidade com frontend atual)
      if (userId) {
        socket.userId = userId;
        return next();
      }

      next(new Error('Autenticação obrigatória'));
    } catch (err) {
      next(new Error('Erro de autenticação'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;

    if (!userId) {
      socket.disconnect();
      return;
    }

    // Registra usuário como online
    onlineUsers.set(userId, socket.id);
    logger.info(`Socket conectado: userId=${userId}`);

    // Entra na sala pessoal
    socket.join(`user:${userId}`);

    // Notifica amigos que ficou online
    const friendIds = await getFriendIds(userId);
    for (const friendId of friendIds) {
      io.to(`user:${friendId}`).emit('user_online', { userId });
    }

    // Entra automaticamente nas salas dos grupos
    const myGroups = await db
      .select({ groupId: chatGroupMembers.groupId })
      .from(chatGroupMembers)
      .where(eq(chatGroupMembers.userId, userId));
    for (const { groupId } of myGroups) {
      socket.join(`group:${groupId}`);
    }

    // ==================
    // ONLINE/OFFLINE
    // ==================

    // Cliente pede lista de amigos online
    socket.on('get_online_friends', async () => {
      const friends = await getFriendIds(userId);
      const onlineFriends = friends.filter(id => onlineUsers.has(id));
      socket.emit('online_friends', { userIds: onlineFriends });
    });

    // ==================
    // TYPING INDICATOR
    // ==================

    socket.on('typing_start', ({ receiverId, groupId }) => {
      if (receiverId) {
        io.to(`user:${receiverId}`).emit('user_typing', { userId, conversationType: 'private' });
      } else if (groupId) {
        socket.to(`group:${groupId}`).emit('user_typing', { userId, conversationType: 'group', groupId });
      }
    });

    socket.on('typing_stop', ({ receiverId, groupId }) => {
      if (receiverId) {
        io.to(`user:${receiverId}`).emit('user_stopped_typing', { userId });
      } else if (groupId) {
        socket.to(`group:${groupId}`).emit('user_stopped_typing', { userId, groupId });
      }
    });

    // ==================
    // READ RECEIPTS
    // ==================

    socket.on('mark_read', async ({ messageIds, senderId }) => {
      try {
        if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) return;

        // Atualiza mensagens privadas
        const { pool } = require('./database');
        await pool.query(`
          UPDATE messages
          SET is_read = true, read_at = NOW()
          WHERE id = ANY($1) AND receiver_id = $2 AND is_read = false
        `, [messageIds, userId]);

        // Insere read receipts (para grupos)
        for (const msgId of messageIds) {
          await db
            .insert(messageReadReceipts)
            .values({ messageId: msgId, userId })
            .onConflictDoNothing();
        }

        // Notifica o remetente que as mensagens foram lidas
        if (senderId) {
          io.to(`user:${senderId}`).emit('messages_read', {
            messageIds,
            readBy: userId,
            readAt: new Date().toISOString(),
          });
        }
      } catch (error) {
        logger.error('Erro ao marcar como lidas:', error);
      }
    });

    // ==================
    // CHAT PRIVADO
    // ==================

    socket.on('send_message', async ({ receiverId, content }) => {
      try {
        if (!receiverId || !content || !content.trim()) return;

        // Verifica amizade
        const [friendship] = await db
          .select()
          .from(friendships)
          .where(
            and(
              eq(friendships.status, 'accepted'),
              or(
                and(eq(friendships.requesterId, userId), eq(friendships.addresseeId, receiverId)),
                and(eq(friendships.requesterId, receiverId), eq(friendships.addresseeId, userId))
              )
            )
          )
          .limit(1);

        if (!friendship) {
          socket.emit('error', { message: 'Vocês não são amigos' });
          return;
        }

        // Salva mensagem no banco
        const [newMessage] = await db
          .insert(messages)
          .values({ senderId: userId, receiverId, content: content.trim() })
          .returning();

        // Busca dados do remetente
        const [sender] = await db
          .select({ id: users.id, displayName: users.displayName, avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, userId))
          .limit(1);

        const messagePayload = { ...newMessage, sender };

        // Envia para o destinatário
        io.to(`user:${receiverId}`).emit('new_message', messagePayload);

        // Confirma para o remetente
        socket.emit('message_sent', messagePayload);

        // Cria notificação
        await db.insert(notifications).values({
          userId: receiverId,
          type: 'new_message',
          title: 'Nova mensagem',
          body: `${sender.displayName}: ${content.trim().substring(0, 60)}`,
          data: { senderId: userId },
        });
      } catch (error) {
        logger.error('Erro ao enviar mensagem:', error);
        socket.emit('error', { message: 'Erro ao enviar mensagem' });
      }
    });

    // ==================
    // CHAT DE GRUPO
    // ==================

    socket.on('join_group', async ({ groupId }) => {
      try {
        const [membership] = await db
          .select()
          .from(chatGroupMembers)
          .where(
            and(
              eq(chatGroupMembers.groupId, groupId),
              eq(chatGroupMembers.userId, userId)
            )
          )
          .limit(1);

        if (!membership) {
          socket.emit('error', { message: 'Você não é membro deste grupo' });
          return;
        }

        socket.join(`group:${groupId}`);
        socket.emit('joined_group', { groupId });
      } catch (error) {
        logger.error('Erro ao entrar no grupo:', error);
      }
    });

    socket.on('send_group_message', async ({ groupId, content }) => {
      try {
        if (!groupId || !content || !content.trim()) return;

        // Verifica membership
        const [membership] = await db
          .select()
          .from(chatGroupMembers)
          .where(
            and(
              eq(chatGroupMembers.groupId, groupId),
              eq(chatGroupMembers.userId, userId)
            )
          )
          .limit(1);

        if (!membership) {
          socket.emit('error', { message: 'Você não é membro deste grupo' });
          return;
        }

        // Salva mensagem
        const [newMessage] = await db
          .insert(messages)
          .values({ senderId: userId, groupId, content: content.trim() })
          .returning();

        // Busca dados do remetente
        const [sender] = await db
          .select({ id: users.id, displayName: users.displayName, avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, userId))
          .limit(1);

        const messagePayload = { ...newMessage, sender };

        // Envia para todos no grupo
        io.to(`group:${groupId}`).emit('new_group_message', messagePayload);
      } catch (error) {
        logger.error('Erro ao enviar mensagem no grupo:', error);
        socket.emit('error', { message: 'Erro ao enviar mensagem' });
      }
    });

    // ==================
    // CHAT DE LIGA
    // ==================

    socket.on('join_league', async ({ leagueId }) => {
      try {
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
          socket.emit('error', { message: 'Você não é membro desta liga' });
          return;
        }

        socket.join(`league:${leagueId}`);
        socket.emit('joined_league', { leagueId });
      } catch (error) {
        logger.error('Erro ao entrar na sala da liga:', error);
      }
    });

    socket.on('send_league_message', async ({ leagueId, content }) => {
      try {
        if (!leagueId || !content || !content.trim()) return;

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
          socket.emit('error', { message: 'Você não é membro desta liga' });
          return;
        }

        const [league] = await db
          .select()
          .from(leagues)
          .where(eq(leagues.id, leagueId))
          .limit(1);

        if (!league) return;

        const isOwner = league.ownerId === userId;

        if (league.chatMode === 'leader_only' && !isOwner) {
          socket.emit('error', { message: 'Apenas o líder pode enviar mensagens neste chat' });
          return;
        }

        if (league.chatMode === 'selected' && !isOwner) {
          const [allowed] = await db
            .select()
            .from(leagueChatAllowed)
            .where(
              and(
                eq(leagueChatAllowed.leagueId, leagueId),
                eq(leagueChatAllowed.userId, userId)
              )
            )
            .limit(1);

          if (!allowed) {
            socket.emit('error', { message: 'Você não tem permissão para enviar mensagens neste chat' });
            return;
          }
        }

        const [newMessage] = await db
          .insert(messages)
          .values({ senderId: userId, leagueId, content: content.trim() })
          .returning();

        const [sender] = await db
          .select({ id: users.id, displayName: users.displayName, avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, userId))
          .limit(1);

        const messagePayload = { ...newMessage, sender };

        io.to(`league:${leagueId}`).emit('new_league_message', messagePayload);
      } catch (error) {
        logger.error('Erro ao enviar mensagem na liga:', error);
        socket.emit('error', { message: 'Erro ao enviar mensagem' });
      }
    });

    // ==================
    // DESCONEXÃO
    // ==================

    // =============================================
    // LIVE: EVENTOS DE SESSAO AO VIVO
    // =============================================

    // Admin/usuario entra na sala da corrida para receber atualizacoes ao vivo
    socket.on('join_race', (raceId) => {
      if (raceId) {
        socket.join(`race:${raceId}`);
        logger.info(`User ${userId} joined race:${raceId}`);
      }
    });

    // Admin/usuario sai da sala da corrida
    socket.on('leave_race', (raceId) => {
      if (raceId) {
        socket.leave(`race:${raceId}`);
        logger.info(`User ${userId} left race:${raceId}`);
      }
    });

        socket.on('disconnect', async () => {
      onlineUsers.delete(userId);
      logger.info(`Socket desconectado: userId=${userId}`);

      // Notifica amigos que ficou offline
      try {
        const friends = await getFriendIds(userId);
        for (const friendId of friends) {
          io.to(`user:${friendId}`).emit('user_offline', { userId });
        }
      } catch (error) {
        logger.error('Erro ao notificar offline:', error);
      }
    });
  });

  return io;
}

// Retorna a instancia do socket.io para uso externo
function getIo() {
  return _io;
}

module.exports = { initSocket, onlineUsers, getIo };
