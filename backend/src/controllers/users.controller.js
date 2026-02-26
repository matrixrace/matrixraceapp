const { db } = require('../config/database');
const { users, friendships, leagues, leagueMembers, scores } = require('../db/schema');
const { eq, ilike, ne, and, or } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

// GET /api/v1/users/search?q=
// Busca usuários por nome ou email (exclui o próprio usuário)
async function searchUsers(req, res, next) {
  try {
    const { q } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({ success: false, message: 'Digite pelo menos 2 caracteres para buscar' });
    }

    const results = await db
      .select({
        id: users.id,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(users)
      .where(
        and(
          ne(users.id, req.user.id),
          or(
            ilike(users.displayName, `%${q.trim()}%`),
            ilike(users.email, `%${q.trim()}%`)
          )
        )
      )
      .limit(20);

    res.json(successResponse(results));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/users/:id
// Retorna perfil público de um usuário
// Estranhos veem: nome e foto apenas
// Amigos veem: nome, foto, bio, ligas e estatísticas
async function getUserProfile(req, res, next) {
  try {
    const { id } = req.params;

    const [targetUser] = await db
      .select({
        id: users.id,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
        bio: users.bio,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.id, id))
      .limit(1);

    if (!targetUser) {
      return next(errorResponse('Usuário não encontrado', 404));
    }

    // Verifica se são amigos
    const [friendship] = await db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.status, 'accepted'),
          or(
            and(eq(friendships.requesterId, req.user.id), eq(friendships.addresseeId, id)),
            and(eq(friendships.requesterId, id), eq(friendships.addresseeId, req.user.id))
          )
        )
      )
      .limit(1);

    const isFriend = !!friendship;
    const isOwnProfile = req.user.id === id;

    // Perfil básico (visível para todos)
    const profile = {
      id: targetUser.id,
      displayName: targetUser.displayName,
      avatarUrl: targetUser.avatarUrl,
      isFriend,
    };

    // Detalhes extras (apenas para amigos ou para si mesmo)
    if (isFriend || isOwnProfile) {
      profile.bio = targetUser.bio;
      profile.memberSince = targetUser.createdAt;

      // Busca ligas ativas
      const userLeagues = await db
        .select({
          leagueId: leagues.id,
          leagueName: leagues.name,
          isPublic: leagues.isPublic,
          status: leagueMembers.status,
        })
        .from(leagueMembers)
        .innerJoin(leagues, eq(leagueMembers.leagueId, leagues.id))
        .where(
          and(
            eq(leagueMembers.userId, id),
            eq(leagueMembers.status, 'active')
          )
        )
        .limit(20);

      profile.leagues = userLeagues;

      // Estatísticas gerais (total de pontos)
      const userScores = await db
        .select({ points: scores.points })
        .from(scores)
        .where(eq(scores.userId, id));

      const totalPoints = userScores.reduce((sum, s) => sum + (s.points || 0), 0);
      profile.stats = {
        totalPoints,
        totalLeagues: userLeagues.length,
      };
    }

    res.json(successResponse(profile));
  } catch (error) {
    next(error);
  }
}

module.exports = { searchUsers, getUserProfile };
