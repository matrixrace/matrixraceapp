const { db } = require('../config/database');
const { users, friendships, notifications } = require('../db/schema');
const { eq, and, or } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// Busca amizade entre dois usuários (em qualquer direção)
async function findFriendship(userId1, userId2) {
  const [friendship] = await db
    .select()
    .from(friendships)
    .where(
      or(
        and(eq(friendships.requesterId, userId1), eq(friendships.addresseeId, userId2)),
        and(eq(friendships.requesterId, userId2), eq(friendships.addresseeId, userId1))
      )
    )
    .limit(1);
  return friendship || null;
}

// GET /api/v1/friends
// Lista todos os amigos aceitos do usuário logado
async function getFriends(req, res, next) {
  try {
    const userId = req.user.id;

    const accepted = await db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.status, 'accepted'),
          or(
            eq(friendships.requesterId, userId),
            eq(friendships.addresseeId, userId)
          )
        )
      );

    // Para cada amizade, busca os dados do outro usuário
    const friendIds = accepted.map(f =>
      f.requesterId === userId ? f.addresseeId : f.requesterId
    );

    const friendList = await Promise.all(
      friendIds.map(async (friendId) => {
        const [user] = await db
          .select({
            id: users.id,
            displayName: users.displayName,
            avatarUrl: users.avatarUrl,
          })
          .from(users)
          .where(eq(users.id, friendId))
          .limit(1);
        return user;
      })
    );

    res.json(successResponse(friendList.filter(Boolean)));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/friends/requests
// Lista pedidos de amizade recebidos pendentes
async function getFriendRequests(req, res, next) {
  try {
    const pending = await db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.addresseeId, req.user.id),
          eq(friendships.status, 'pending')
        )
      );

    const requests = await Promise.all(
      pending.map(async (f) => {
        const [requester] = await db
          .select({
            id: users.id,
            displayName: users.displayName,
            avatarUrl: users.avatarUrl,
          })
          .from(users)
          .where(eq(users.id, f.requesterId))
          .limit(1);
        return { friendshipId: f.id, user: requester, createdAt: f.createdAt };
      })
    );

    res.json(successResponse(requests.filter(r => r.user)));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/friends/request/:userId
// Envia pedido de amizade para outro usuário
async function sendFriendRequest(req, res, next) {
  try {
    const requesterId = req.user.id;
    const addresseeId = req.params.userId;

    if (requesterId === addresseeId) {
      return next(errorResponse('Você não pode se adicionar como amigo', 400));
    }

    // Verifica se o destinatário existe
    const [addressee] = await db
      .select({ id: users.id, displayName: users.displayName })
      .from(users)
      .where(eq(users.id, addresseeId))
      .limit(1);

    if (!addressee) {
      return next(errorResponse('Usuário não encontrado', 404));
    }

    // Verifica se já existe amizade/pedido
    const existing = await findFriendship(requesterId, addresseeId);
    if (existing) {
      if (existing.status === 'accepted') {
        return next(errorResponse('Vocês já são amigos', 400));
      }
      if (existing.status === 'pending') {
        return next(errorResponse('Já existe um pedido de amizade pendente', 400));
      }
    }

    // Cria o pedido
    const [newFriendship] = await db
      .insert(friendships)
      .values({ requesterId, addresseeId, status: 'pending' })
      .returning();

    // Cria notificação para o destinatário
    await db.insert(notifications).values({
      userId: addresseeId,
      type: 'friend_request',
      title: 'Pedido de amizade',
      body: `${req.user.displayName} quer ser seu amigo!`,
      data: { friendshipId: newFriendship.id, senderId: requesterId },
    });

    res.status(201).json(successResponse(newFriendship, 'Pedido de amizade enviado'));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/friends/:friendshipId/accept
// Aceita um pedido de amizade
async function acceptFriendRequest(req, res, next) {
  try {
    const { friendshipId } = req.params;

    const [friendship] = await db
      .select()
      .from(friendships)
      .where(eq(friendships.id, friendshipId))
      .limit(1);

    if (!friendship) {
      return next(errorResponse('Pedido não encontrado', 404));
    }

    if (friendship.addresseeId !== req.user.id) {
      return next(errorResponse('Sem permissão para aceitar este pedido', 403));
    }

    if (friendship.status !== 'pending') {
      return next(errorResponse('Este pedido já foi processado', 400));
    }

    const [updated] = await db
      .update(friendships)
      .set({ status: 'accepted', updatedAt: new Date() })
      .where(eq(friendships.id, friendshipId))
      .returning();

    // Notifica o solicitante que foi aceito
    await db.insert(notifications).values({
      userId: friendship.requesterId,
      type: 'friend_accepted',
      title: 'Pedido aceito!',
      body: `${req.user.displayName} aceitou seu pedido de amizade!`,
      data: { friendshipId: updated.id, userId: req.user.id },
    });

    res.json(successResponse(updated, 'Pedido de amizade aceito'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/friends/:friendshipId
// Recusa um pedido ou desfaz amizade
async function removeFriend(req, res, next) {
  try {
    const { friendshipId } = req.params;
    const userId = req.user.id;

    const [friendship] = await db
      .select()
      .from(friendships)
      .where(eq(friendships.id, friendshipId))
      .limit(1);

    if (!friendship) {
      return next(errorResponse('Amizade não encontrada', 404));
    }

    // Apenas os dois envolvidos podem remover
    if (friendship.requesterId !== userId && friendship.addresseeId !== userId) {
      return next(errorResponse('Sem permissão', 403));
    }

    await db.delete(friendships).where(eq(friendships.id, friendshipId));

    res.json(successResponse(null, 'Amizade removida'));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getFriends,
  getFriendRequests,
  sendFriendRequest,
  acceptFriendRequest,
  removeFriend,
};
