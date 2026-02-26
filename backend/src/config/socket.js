const { Server } = require('socket.io');
const { db } = require('./database');
const { messages, friendships, leagueMembers, leagues, leagueChatAllowed, users, notifications } = require('../db/schema');
const { eq, and, or } = require('drizzle-orm');
const logger = require('../utils/logger');

// Mapa: userId -> socketId (para saber se usuário está online)
const onlineUsers = new Map();

function initSocket(httpServer, corsOrigin) {
  const io = new Server(httpServer, {
    cors: {
      origin: corsOrigin,
      methods: ['GET', 'POST'],
      credentials: true,
    },
  });

  io.on('connection', (socket) => {
    const userId = socket.handshake.auth.userId;

    if (!userId) {
      socket.disconnect();
      return;
    }

    // Registra usuário como online
    onlineUsers.set(userId, socket.id);
    logger.info(`Socket conectado: userId=${userId}`);

    // Entra automaticamente na sala pessoal (para receber notificações)
    socket.join(`user:${userId}`);

    // ==================
    // CHAT PRIVADO
    // ==================

    // Enviar mensagem privada para um amigo
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

        // Envia para o destinatário (se estiver online)
        io.to(`user:${receiverId}`).emit('new_message', messagePayload);

        // Confirma para o remetente
        socket.emit('message_sent', messagePayload);

        // Cria notificação para o destinatário (se não estiver na conversa)
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
    // CHAT DE LIGA
    // ==================

    // Entrar na sala de uma liga
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

    // Enviar mensagem no chat da liga
    socket.on('send_league_message', async ({ leagueId, content }) => {
      try {
        if (!leagueId || !content || !content.trim()) return;

        // Verifica se é membro ativo
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

        // Verifica permissão de escrita
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

        // Salva mensagem
        const [newMessage] = await db
          .insert(messages)
          .values({ senderId: userId, leagueId, content: content.trim() })
          .returning();

        // Busca dados do remetente
        const [sender] = await db
          .select({ id: users.id, displayName: users.displayName, avatarUrl: users.avatarUrl })
          .from(users)
          .where(eq(users.id, userId))
          .limit(1);

        const messagePayload = { ...newMessage, sender };

        // Envia para todos na sala da liga
        io.to(`league:${leagueId}`).emit('new_league_message', messagePayload);

      } catch (error) {
        logger.error('Erro ao enviar mensagem na liga:', error);
        socket.emit('error', { message: 'Erro ao enviar mensagem' });
      }
    });

    // ==================
    // DESCONEXÃO
    // ==================

    socket.on('disconnect', () => {
      onlineUsers.delete(userId);
      logger.info(`Socket desconectado: userId=${userId}`);
    });
  });

  return io;
}

module.exports = { initSocket, onlineUsers };
