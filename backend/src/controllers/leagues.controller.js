const { db, pool } = require('../config/database');
const { leagues, leagueMembers, leagueRaces, invitations, users } = require('../db/schema');
const { eq, and, desc } = require('drizzle-orm');
const { successResponse, errorResponse, generateInviteCode } = require('../utils/helpers');
const { sendLeagueInvite } = require('../services/email.service');
const config = require('../config/environment');
const logger = require('../utils/logger');

// GET /api/v1/leagues
// Lista as ligas do usuário logado
// Query param opcional: raceId (filtra apenas ligas que contêm essa corrida)
async function getMyLeagues(req, res, next) {
  try {
    const { raceId } = req.query;

    let query;
    let params;

    if (raceId) {
      // Retorna apenas ligas que o usuário é membro E que contêm essa corrida
      query = `SELECT l.*,
        COUNT(DISTINCT lm2.user_id) as member_count,
        COUNT(DISTINCT lr_count.race_id) as race_count,
        (SELECT COALESCE(SUM(s.points), 0) FROM scores s
         WHERE s.league_id = l.id AND s.user_id = $1) as my_points
       FROM league_members lm
       JOIN leagues l ON l.id = lm.league_id
       JOIN league_races lr ON lr.league_id = l.id AND lr.race_id = $2
       LEFT JOIN league_members lm2 ON lm2.league_id = l.id
         AND lm2.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
         AND lm2.status = 'active'
       LEFT JOIN league_races lr_count ON lr_count.league_id = l.id
       WHERE lm.user_id = $1 AND lm.status = 'active'
       GROUP BY l.id
       ORDER BY l.created_at DESC`;
      params = [req.user.id, parseInt(raceId)];
    } else {
      query = `SELECT l.*,
        COUNT(DISTINCT lm2.user_id) as member_count,
        COUNT(DISTINCT lr_count.race_id) as race_count,
        (SELECT COALESCE(SUM(s.points), 0) FROM scores s
         WHERE s.league_id = l.id AND s.user_id = $1) as my_points
       FROM league_members lm
       JOIN leagues l ON l.id = lm.league_id
       LEFT JOIN league_members lm2 ON lm2.league_id = l.id
         AND lm2.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
         AND lm2.status = 'active'
       LEFT JOIN league_races lr_count ON lr_count.league_id = l.id
       WHERE lm.user_id = $1 AND lm.status = 'active'
       GROUP BY l.id
       ORDER BY l.created_at DESC`;
      params = [req.user.id];
    }

    const result = await pool.query(query, params);
    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/public
// Lista ligas públicas (não precisa de login)
// Quando autenticado, inclui user_member_status para cada liga
async function getPublicLeagues(req, res, next) {
  try {
    // status: 'active' (padrão) = tem GPs futuros | 'ended' = todos os GPs ocorreram
    const rawStatus = req.query.status;
    const status = rawStatus === 'ended' ? 'ended' : rawStatus === 'all' ? 'all' : 'active';
    const userId = req.user?.id || null;
    const raceId = req.query.raceId || null;

    // HAVING para cada status:
    const havingClause = status === 'ended'
      ? `HAVING COUNT(lr.race_id) FILTER (WHERE r.race_date > NOW() AND r.is_completed = false) = 0
              AND COUNT(lr.race_id) > 0`
      : status === 'all'
      ? ``
      : `HAVING COUNT(lr.race_id) FILTER (WHERE r.race_date > NOW() AND r.is_completed = false) > 0
              OR  COUNT(lr.race_id) = 0`;

    const orderClause = status === 'active'
      ? `ORDER BY past_race_count ASC, member_count DESC, l.created_at ASC`
      : `ORDER BY member_count DESC, l.created_at ASC`;

    const params = [];
    let paramIdx = 1;

    const userStatusSelect = userId
      ? `(SELECT lm_u.status FROM league_members lm_u
          WHERE lm_u.league_id = l.id AND lm_u.user_id = $${paramIdx}) as user_member_status,`
      : `null as user_member_status,`;
    if (userId) { params.push(userId); paramIdx++; }

    // Filtro opcional de GP: exige que a liga tenha aquele race_id
    const raceJoin = raceId
      ? `JOIN league_races lr_gp ON lr_gp.league_id = l.id AND lr_gp.race_id = $${paramIdx}`
      : ``;
    if (raceId) { params.push(raceId); paramIdx++; }

    const query = `
      SELECT l.*, u.display_name as owner_name,
        COUNT(DISTINCT lm.user_id) as member_count,
        ${userStatusSelect}
        COUNT(lr.race_id) FILTER (WHERE r.race_date > NOW() AND r.is_completed = false) as future_race_count,
        COUNT(lr.race_id) FILTER (WHERE r.race_date <= NOW() OR r.is_completed = true)  as past_race_count
      FROM leagues l
      JOIN users u ON u.id = l.owner_id
      ${raceJoin}
      LEFT JOIN league_members lm ON lm.league_id = l.id
        AND lm.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
        AND lm.status = 'active'
      LEFT JOIN league_races lr ON lr.league_id = l.id
      LEFT JOIN races r ON r.id = lr.race_id
      WHERE l.is_public = true
      GROUP BY l.id, u.display_name
      ${havingClause}
      ${orderClause}
      LIMIT 200`;

    const result = await pool.query(query, params);
    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/:id
// Detalhes de uma liga
async function getLeague(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT l.*,
        u.display_name as owner_name,
        COUNT(DISTINCT lm.user_id) as member_count
       FROM leagues l
       JOIN users u ON u.id = l.owner_id
       LEFT JOIN league_members lm ON lm.league_id = l.id
         AND lm.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
         AND lm.status = 'active'
       WHERE l.id = $1
       GROUP BY l.id, u.display_name`,
      [id]
    );

    if (result.rows.length === 0) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    // Busca corridas da liga
    const racesResult = await pool.query(
      `SELECT r.* FROM league_races lr
       JOIN races r ON r.id = lr.race_id
       WHERE lr.league_id = $1
       ORDER BY r.race_date`,
      [id]
    );

    const league = result.rows[0];
    league.races = racesResult.rows;

    res.json(successResponse(league));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/leagues
// Cria uma nova liga
async function createLeague(req, res, next) {
  try {
    const { name, description, isPublic, requiresApproval, maxMembers, raceIds } = req.body;

    // Gera código de convite único
    const inviteCode = generateInviteCode();

    // Liga privada sempre exige aprovação
    const approval = !isPublic ? true : (requiresApproval ?? false);

    // Cria a liga
    const [league] = await db
      .insert(leagues)
      .values({
        name,
        description,
        ownerId: req.user.id,
        isPublic,
        requiresApproval: approval,
        maxMembers,
        inviteCode,
      })
      .returning();

    // Adiciona o criador como membro
    await db.insert(leagueMembers).values({
      leagueId: league.id,
      userId: req.user.id,
    });

    // Associa corridas à liga
    if (raceIds && raceIds.length > 0) {
      const raceValues = raceIds.map((raceId) => ({
        leagueId: league.id,
        raceId,
      }));
      await db.insert(leagueRaces).values(raceValues);
    }

    logger.info(`Liga criada: "${name}" por ${req.user.email}`);
    res.status(201).json(successResponse(league, 'Liga criada com sucesso'));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/leagues/:id
// Edita uma liga (somente o dono)
async function updateLeague(req, res, next) {
  try {
    const { id } = req.params;

    // Verifica se é o dono
    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, id))
      .limit(1);

    if (!league) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    if (league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o dono pode editar a liga', 403));
    }

    const [updated] = await db
      .update(leagues)
      .set({ ...req.body, updatedAt: new Date() })
      .where(eq(leagues.id, id))
      .returning();

    res.json(successResponse(updated, 'Liga atualizada'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/leagues/:id
// Deleta uma liga (somente o dono)
async function deleteLeague(req, res, next) {
  try {
    const { id } = req.params;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, id))
      .limit(1);

    if (!league) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    if (league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o dono pode deletar a liga', 403));
    }

    await db.delete(leagues).where(eq(leagues.id, id));

    res.json(successResponse(null, 'Liga deletada'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/leagues/:id/join
// Entrar em uma liga pública
async function joinLeague(req, res, next) {
  try {
    if (req.user.isAdmin) {
      return next(errorResponse('Administradores não participam de ligas', 403));
    }

    const { id } = req.params;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, id))
      .limit(1);

    if (!league) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    if (!league.isPublic) {
      return next(errorResponse('Esta liga é privada. Use o código de convite.', 403));
    }

    // Verifica limite de membros
    if (league.maxMembers) {
      const count = await pool.query(
        'SELECT COUNT(*) as total FROM league_members lm JOIN users u ON u.id = lm.user_id WHERE lm.league_id = $1 AND u.is_admin = false',
        [id]
      );
      if (parseInt(count.rows[0].total) >= league.maxMembers) {
        return next(errorResponse('Liga está cheia', 400));
      }
    }

    // Liga pública com aprovação = pending; sem aprovação = active
    const joinStatus = league.requiresApproval ? 'pending' : 'active';
    await db.insert(leagueMembers).values({
      leagueId: id,
      userId: req.user.id,
      status: joinStatus,
    });

    const joinMessage = joinStatus === 'pending'
      ? 'Solicitação enviada! Aguarde a aprovação do líder da liga.'
      : 'Você entrou na liga!';
    res.json(successResponse(null, joinMessage));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Você já está nesta liga', 409));
    }
    next(error);
  }
}

// POST /api/v1/leagues/join-by-code
// Entrar em uma liga usando código de convite
async function joinByCode(req, res, next) {
  try {
    if (req.user.isAdmin) {
      return next(errorResponse('Administradores não participam de ligas', 403));
    }

    const { code } = req.body;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.inviteCode, code.toUpperCase()))
      .limit(1);

    if (!league) {
      return next(errorResponse('Código de convite inválido', 404));
    }

    // Verifica limite de membros
    if (league.maxMembers) {
      const result = await pool.query(
        'SELECT COUNT(*) as total FROM league_members lm JOIN users u ON u.id = lm.user_id WHERE lm.league_id = $1 AND u.is_admin = false',
        [league.id]
      );
      if (parseInt(result.rows[0].total) >= league.maxMembers) {
        return next(errorResponse('Liga está cheia', 400));
      }
    }

    // Qualquer liga que exige aprovação (privada ou pública com aprovação) = pending
    const status = league.requiresApproval ? 'pending' : 'active';
    await db.insert(leagueMembers).values({
      leagueId: league.id,
      userId: req.user.id,
      status,
    });

    const message = status === 'pending'
      ? 'Solicitação enviada! Aguarde a aprovação do líder da liga.'
      : 'Você entrou na liga!';
    res.json(successResponse({ league }, message));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Você já está nesta liga', 409));
    }
    next(error);
  }
}

// POST /api/v1/leagues/:id/invite
// Convidar alguém por email
async function inviteMember(req, res, next) {
  try {
    const { id } = req.params;
    const { email } = req.body;

    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, id))
      .limit(1);

    if (!league) {
      return next(errorResponse('Liga não encontrada', 404));
    }

    // Salva convite
    await db.insert(invitations).values({
      leagueId: id,
      invitedBy: req.user.id,
      email,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 dias
    });

    // Envia email
    const inviteLink = `${config.frontendUrl}/join/${league.inviteCode}`;
    sendLeagueInvite({
      to: email,
      leagueName: league.name,
      invitedByName: req.user.displayName || 'Um amigo',
      inviteLink,
    }).catch(() => {});

    res.json(successResponse(null, 'Convite enviado!'));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Convite já enviado para este email', 409));
    }
    next(error);
  }
}

// GET /api/v1/leagues/:id/members
// Lista membros de uma liga
async function getMembers(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT u.id, u.display_name, u.avatar_url, lm.joined_at
       FROM league_members lm
       JOIN users u ON u.id = lm.user_id
       WHERE lm.league_id = $1 AND u.is_admin = false AND lm.status = 'active'
       ORDER BY lm.joined_at`,
      [id]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/leagues/:id/members/:userId
// Remove membro da liga (somente o dono)
async function removeMember(req, res, next) {
  try {
    const { id, userId } = req.params;

    // Verifica se é o dono
    const [league] = await db
      .select()
      .from(leagues)
      .where(eq(leagues.id, id))
      .limit(1);

    if (!league || league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o dono pode remover membros', 403));
    }

    if (userId === req.user.id) {
      return next(errorResponse('Você não pode se remover da própria liga', 400));
    }

    await db
      .delete(leagueMembers)
      .where(
        and(
          eq(leagueMembers.leagueId, id),
          eq(leagueMembers.userId, userId)
        )
      );

    res.json(successResponse(null, 'Membro removido'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/public-for-prediction?raceId=X
// Ligas públicas (sem aprovação) que contêm aquela corrida e o usuário ainda não é membro
async function getPublicLeaguesForPrediction(req, res, next) {
  try {
    const raceId = parseInt(req.query.raceId);
    if (!raceId) return next(errorResponse('raceId é obrigatório', 400));

    const result = await pool.query(
      `SELECT l.*,
        u.display_name as owner_name,
        COUNT(DISTINCT lm2.user_id) as member_count
       FROM leagues l
       JOIN users u ON u.id = l.owner_id
       JOIN league_races lr ON lr.league_id = l.id AND lr.race_id = $2
       LEFT JOIN league_members lm2 ON lm2.league_id = l.id
         AND lm2.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
         AND lm2.status = 'active'
       WHERE l.is_public = true
         AND l.is_official = false
         AND l.requires_approval = false
         AND l.id NOT IN (
           SELECT league_id FROM league_members
           WHERE user_id = $1 AND status = 'active'
         )
       GROUP BY l.id, u.display_name
       ORDER BY l.created_at DESC`,
      [req.user.id, raceId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/:id/races-status
// Corridas da liga com status de palpite do usuário logado
async function getLeagueRacesStatus(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT
        r.id, r.name, r.round, r.race_date, r.fp1_date, r.qualifying_date,
        r.is_completed, r.circuit_name, r.location, r.country,
        EXISTS(
          SELECT 1 FROM predictions WHERE race_id = r.id AND user_id = $2
        ) as has_prediction,
        EXISTS(
          SELECT 1 FROM prediction_applications
          WHERE league_id = $1 AND race_id = r.id AND user_id = $2
        ) as prediction_applied
       FROM league_races lr
       JOIN races r ON r.id = lr.race_id
       WHERE lr.league_id = $1
       ORDER BY r.race_date`,
      [id, userId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/leagues/:id/requests
// Lista solicitações pendentes (somente o dono)
async function getPendingRequests(req, res, next) {
  try {
    const { id } = req.params;

    const [league] = await db.select().from(leagues).where(eq(leagues.id, id)).limit(1);
    if (!league || league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o líder pode ver solicitações pendentes', 403));
    }

    const result = await pool.query(
      `SELECT u.id, u.display_name, u.avatar_url, lm.joined_at
       FROM league_members lm
       JOIN users u ON u.id = lm.user_id
       WHERE lm.league_id = $1 AND lm.status = 'pending'
       ORDER BY lm.joined_at`,
      [id]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/leagues/:id/requests/:userId/approve
// Aprovar solicitação de entrada (somente o dono)
async function approveRequest(req, res, next) {
  try {
    const { id, userId } = req.params;

    const [league] = await db.select().from(leagues).where(eq(leagues.id, id)).limit(1);
    if (!league || league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o líder pode aprovar solicitações', 403));
    }

    const result = await pool.query(
      `UPDATE league_members SET status = 'active'
       WHERE league_id = $1 AND user_id = $2 AND status = 'pending'
       RETURNING *`,
      [id, userId]
    );

    if (result.rowCount === 0) {
      return next(errorResponse('Solicitação não encontrada', 404));
    }

    res.json(successResponse(null, 'Membro aprovado!'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/leagues/:id/requests/:userId
// Rejeitar/cancelar solicitação de entrada (somente o dono)
async function rejectRequest(req, res, next) {
  try {
    const { id, userId } = req.params;

    const [league] = await db.select().from(leagues).where(eq(leagues.id, id)).limit(1);
    if (!league || league.ownerId !== req.user.id) {
      return next(errorResponse('Apenas o líder pode rejeitar solicitações', 403));
    }

    await pool.query(
      `DELETE FROM league_members WHERE league_id = $1 AND user_id = $2 AND status = 'pending'`,
      [id, userId]
    );

    res.json(successResponse(null, 'Solicitação rejeitada'));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getMyLeagues, getPublicLeagues, getLeague,
  createLeague, updateLeague, deleteLeague,
  joinLeague, joinByCode, inviteMember,
  getMembers, removeMember,
  getPendingRequests, approveRequest, rejectRequest,
  getPublicLeaguesForPrediction,
  getLeagueRacesStatus,
};
