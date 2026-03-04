const { db } = require('../config/database');
const {
  chatGroups,
  chatGroupMembers,
  messages,
  users,
  friendships,
  messageReadReceipts,
} = require('../db/schema');
const { eq, and, or, asc, desc, inArray, sql } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// Helper: verifica se dois usuários são amigos
async function areFriends(userId1, userId2) {
  const [friendship] = await db
    .select()
    .from(friendships)
    .where(
      and(
        eq(friendships.status, 'accepted'),
        or(
          and(eq(friendships.requesterId, userId1), eq(friendships.addresseeId, userId2)),
          and(eq(friendships.requesterId, userId2), eq(friendships.addresseeId, userId1))
        )
      )
    )
    .limit(1);
  return !!friendship;
}

// POST /api/v1/chat-groups
// Criar um grupo de chat e adicionar membros (apenas amigos)
async function createGroup(req, res, next) {
  try {
    const userId = req.user.id;
    const { name, memberIds } = req.body;

    if (!name || !name.trim()) {
      return next(errorResponse('Nome do grupo é obrigatório', 400));
    }

    if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
      return next(errorResponse('Adicione pelo menos um amigo ao grupo', 400));
    }

    // Verifica que todos os memberIds são amigos do criador
    for (const memberId of memberIds) {
      const isFriend = await areFriends(userId, memberId);
      if (!isFriend) {
        return next(errorResponse(`Usuário ${memberId} não é seu amigo`, 400));
      }
    }

    // Cria o grupo
    const [group] = await db
      .insert(chatGroups)
      .values({
        name: name.trim(),
        creatorId: userId,
      })
      .returning();

    // Adiciona o criador como admin
    await db.insert(chatGroupMembers).values({
      groupId: group.id,
      userId: userId,
      role: 'admin',
    });

    // Adiciona os membros
    for (const memberId of memberIds) {
      await db.insert(chatGroupMembers).values({
        groupId: group.id,
        userId: memberId,
        role: 'member',
      });
    }

    // Busca membros com dados do usuário
    const members = await db
      .select({
        userId: chatGroupMembers.userId,
        role: chatGroupMembers.role,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(chatGroupMembers)
      .innerJoin(users, eq(chatGroupMembers.userId, users.id))
      .where(eq(chatGroupMembers.groupId, group.id));

    res.status(201).json(successResponse({ ...group, members }, 'Grupo criado com sucesso'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/chat-groups
// Listar todos os grupos do usuário com última mensagem e unread count
async function getMyGroups(req, res, next) {
  try {
    const userId = req.user.id;

    // Busca todos os grupos do usuário
    const myMemberships = await db
      .select({
        groupId: chatGroupMembers.groupId,
        role: chatGroupMembers.role,
      })
      .from(chatGroupMembers)
      .where(eq(chatGroupMembers.userId, userId));

    if (myMemberships.length === 0) {
      return res.json(successResponse([]));
    }

    const groupIds = myMemberships.map(m => m.groupId);

    // Busca dados dos grupos
    const groups = await db
      .select()
      .from(chatGroups)
      .where(inArray(chatGroups.id, groupIds));

    // Para cada grupo, busca última mensagem e unread count
    const result = await Promise.all(
      groups.map(async (group) => {
        // Última mensagem
        const [lastMsg] = await db
          .select({
            content: messages.content,
            createdAt: messages.createdAt,
            senderName: users.displayName,
          })
          .from(messages)
          .innerJoin(users, eq(messages.senderId, users.id))
          .where(eq(messages.groupId, group.id))
          .orderBy(desc(messages.createdAt))
          .limit(1);

        // Unread count: mensagens do grupo que não foram lidas por este usuário
        const [unreadResult] = await db
          .select({ count: sql`COUNT(*)` })
          .from(messages)
          .where(
            and(
              eq(messages.groupId, group.id),
              sql`${messages.senderId} != ${userId}`,
              sql`${messages.id} NOT IN (
                SELECT message_id FROM message_read_receipts
                WHERE user_id = ${userId}
              )`
            )
          );

        // Membros count
        const [memberCount] = await db
          .select({ count: sql`COUNT(*)` })
          .from(chatGroupMembers)
          .where(eq(chatGroupMembers.groupId, group.id));

        return {
          ...group,
          role: myMemberships.find(m => m.groupId === group.id)?.role,
          memberCount: parseInt(memberCount.count),
          lastMessage: lastMsg || null,
          unreadCount: parseInt(unreadResult.count),
        };
      })
    );

    // Ordena por última mensagem
    result.sort((a, b) => {
      const dateA = a.lastMessage?.createdAt || a.createdAt;
      const dateB = b.lastMessage?.createdAt || b.createdAt;
      return new Date(dateB) - new Date(dateA);
    });

    res.json(successResponse(result));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/chat-groups/:groupId
// Detalhes de um grupo + membros
async function getGroupDetails(req, res, next) {
  try {
    const userId = req.user.id;
    const { groupId } = req.params;

    // Verifica se é membro
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
      return next(errorResponse('Você não é membro deste grupo', 403));
    }

    const [group] = await db
      .select()
      .from(chatGroups)
      .where(eq(chatGroups.id, groupId))
      .limit(1);

    if (!group) {
      return next(errorResponse('Grupo não encontrado', 404));
    }

    const members = await db
      .select({
        userId: chatGroupMembers.userId,
        role: chatGroupMembers.role,
        joinedAt: chatGroupMembers.joinedAt,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(chatGroupMembers)
      .innerJoin(users, eq(chatGroupMembers.userId, users.id))
      .where(eq(chatGroupMembers.groupId, groupId));

    res.json(successResponse({ ...group, members }));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/chat-groups/:groupId
// Editar grupo (apenas admin)
async function updateGroup(req, res, next) {
  try {
    const userId = req.user.id;
    const { groupId } = req.params;
    const { name } = req.body;

    const [membership] = await db
      .select()
      .from(chatGroupMembers)
      .where(
        and(
          eq(chatGroupMembers.groupId, groupId),
          eq(chatGroupMembers.userId, userId),
          eq(chatGroupMembers.role, 'admin')
        )
      )
      .limit(1);

    if (!membership) {
      return next(errorResponse('Apenas administradores podem editar o grupo', 403));
    }

    const updateData = { updatedAt: new Date() };
    if (name && name.trim()) updateData.name = name.trim();

    const [updated] = await db
      .update(chatGroups)
      .set(updateData)
      .where(eq(chatGroups.id, groupId))
      .returning();

    res.json(successResponse(updated, 'Grupo atualizado'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/chat-groups/:groupId/members
// Adicionar membros ao grupo (apenas admin, apenas amigos)
async function addMembers(req, res, next) {
  try {
    const userId = req.user.id;
    const { groupId } = req.params;
    const { userIds } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return next(errorResponse('Informe os usuários para adicionar', 400));
    }

    // Verifica se é admin
    const [membership] = await db
      .select()
      .from(chatGroupMembers)
      .where(
        and(
          eq(chatGroupMembers.groupId, groupId),
          eq(chatGroupMembers.userId, userId),
          eq(chatGroupMembers.role, 'admin')
        )
      )
      .limit(1);

    if (!membership) {
      return next(errorResponse('Apenas administradores podem adicionar membros', 403));
    }

    // Verifica amizade e adiciona
    const added = [];
    for (const newUserId of userIds) {
      const isFriend = await areFriends(userId, newUserId);
      if (!isFriend) continue;

      try {
        await db.insert(chatGroupMembers).values({
          groupId,
          userId: newUserId,
          role: 'member',
        });
        added.push(newUserId);
      } catch (e) {
        // Ignora duplicados
      }
    }

    res.json(successResponse({ added }, `${added.length} membro(s) adicionado(s)`));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/chat-groups/:groupId/members/:userId
// Remover membro (admin) ou sair do grupo (self)
async function removeMember(req, res, next) {
  try {
    const currentUserId = req.user.id;
    const { groupId, userId: targetUserId } = req.params;

    const isSelf = currentUserId === targetUserId;

    if (!isSelf) {
      // Precisa ser admin para remover outro
      const [adminCheck] = await db
        .select()
        .from(chatGroupMembers)
        .where(
          and(
            eq(chatGroupMembers.groupId, groupId),
            eq(chatGroupMembers.userId, currentUserId),
            eq(chatGroupMembers.role, 'admin')
          )
        )
        .limit(1);

      if (!adminCheck) {
        return next(errorResponse('Apenas administradores podem remover membros', 403));
      }
    }

    await db
      .delete(chatGroupMembers)
      .where(
        and(
          eq(chatGroupMembers.groupId, groupId),
          eq(chatGroupMembers.userId, targetUserId)
        )
      );

    // Se saiu e era o último admin, promove o membro mais antigo
    if (isSelf) {
      const [remainingAdmin] = await db
        .select()
        .from(chatGroupMembers)
        .where(
          and(
            eq(chatGroupMembers.groupId, groupId),
            eq(chatGroupMembers.role, 'admin')
          )
        )
        .limit(1);

      if (!remainingAdmin) {
        const [oldestMember] = await db
          .select()
          .from(chatGroupMembers)
          .where(eq(chatGroupMembers.groupId, groupId))
          .orderBy(asc(chatGroupMembers.joinedAt))
          .limit(1);

        if (oldestMember) {
          await db
            .update(chatGroupMembers)
            .set({ role: 'admin' })
            .where(eq(chatGroupMembers.id, oldestMember.id));
        } else {
          // Grupo vazio, deleta
          await db.delete(chatGroups).where(eq(chatGroups.id, groupId));
        }
      }
    }

    res.json(successResponse(null, isSelf ? 'Você saiu do grupo' : 'Membro removido'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/chat-groups/:groupId/messages
// Histórico de mensagens do grupo (paginado)
async function getGroupMessages(req, res, next) {
  try {
    const userId = req.user.id;
    const { groupId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

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
      return next(errorResponse('Você não é membro deste grupo', 403));
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
      .where(eq(messages.groupId, groupId))
      .orderBy(asc(messages.createdAt))
      .limit(limit)
      .offset(offset);

    // Marca mensagens como lidas (insere read receipts)
    const unreadMsgIds = [];
    for (const msg of history) {
      if (msg.senderId !== userId) {
        unreadMsgIds.push(msg.id);
      }
    }

    if (unreadMsgIds.length > 0) {
      for (const msgId of unreadMsgIds) {
        await db
          .insert(messageReadReceipts)
          .values({ messageId: msgId, userId })
          .onConflictDoNothing();
      }
    }

    res.json(successResponse(history));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  createGroup,
  getMyGroups,
  getGroupDetails,
  updateGroup,
  addMembers,
  removeMember,
  getGroupMessages,
};
