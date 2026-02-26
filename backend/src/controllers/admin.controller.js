const { db, pool } = require('../config/database');
const { teams, drivers, races, raceResults, leagues, leagueRaces, leagueMembers } = require('../db/schema');
const { eq, and } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');
const { uploadImage, deleteImage } = require('../services/storage.service');
const { calculateRaceScores } = require('../services/scoring.service');
const logger = require('../utils/logger');

// ==================
// DASHBOARD
// ==================

// GET /api/v1/admin/dashboard
async function getDashboardStats(req, res, next) {
  try {
    const stats = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM races) as total_races,
        (SELECT COUNT(*) FROM races WHERE is_completed = true) as completed_races,
        (SELECT COUNT(*) FROM leagues) as total_leagues,
        (SELECT COUNT(*) FROM leagues WHERE is_official = true) as official_leagues,
        (SELECT COUNT(*) FROM predictions) as total_predictions,
        (SELECT COUNT(*) FROM league_members) as total_memberships
    `);

    const nextRaces = await pool.query(`
      SELECT id, name, round, race_date, fp1_date, qualifying_date, is_completed
      FROM races
      WHERE is_completed = false
      ORDER BY race_date ASC
      LIMIT 5
    `);

    res.json(successResponse({
      stats: stats.rows[0],
      nextRaces: nextRaces.rows,
    }));
  } catch (error) {
    next(error);
  }
}

// ==================
// EQUIPES (TEAMS)
// ==================

// GET /api/v1/admin/teams
async function getTeams(req, res, next) {
  try {
    const allTeams = await db.select().from(teams).orderBy(teams.name);
    res.json(successResponse(allTeams));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/teams
async function createTeam(req, res, next) {
  try {
    const [team] = await db.insert(teams).values(req.body).returning();
    logger.info(`Equipe criada: ${team.name}`);
    res.status(201).json(successResponse(team, 'Equipe criada com sucesso'));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Já existe uma equipe com este nome', 409));
    }
    next(error);
  }
}

// PUT /api/v1/admin/teams/:id
async function updateTeam(req, res, next) {
  try {
    const { id } = req.params;
    const [team] = await db
      .update(teams)
      .set({ ...req.body, updatedAt: new Date() })
      .where(eq(teams.id, parseInt(id)))
      .returning();

    if (!team) {
      return next(errorResponse('Equipe não encontrada', 404));
    }

    res.json(successResponse(team, 'Equipe atualizada'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/admin/teams/:id
async function deleteTeam(req, res, next) {
  try {
    const { id } = req.params;
    const [team] = await db
      .delete(teams)
      .where(eq(teams.id, parseInt(id)))
      .returning();

    if (!team) {
      return next(errorResponse('Equipe não encontrada', 404));
    }

    res.json(successResponse(null, 'Equipe deletada'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/teams/:id/logo
async function uploadTeamLogo(req, res, next) {
  try {
    if (!req.file) {
      return next(errorResponse('Nenhuma imagem enviada', 400));
    }

    const { id } = req.params;
    const { url } = await uploadImage(req.file.buffer, 'teams', { width: 200, height: 200 });

    const [team] = await db
      .update(teams)
      .set({ logoUrl: url, updatedAt: new Date() })
      .where(eq(teams.id, parseInt(id)))
      .returning();

    if (!team) {
      return next(errorResponse('Equipe não encontrada', 404));
    }

    res.json(successResponse(team, 'Logo enviado'));
  } catch (error) {
    next(error);
  }
}

// ==================
// PILOTOS (DRIVERS)
// ==================

// GET /api/v1/admin/drivers
async function getDrivers(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT d.*, t.name as team_name, t.color_primary as team_color
       FROM drivers d
       LEFT JOIN teams t ON t.id = d.team_id
       ORDER BY d.last_name`
    );
    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/drivers
async function createDriver(req, res, next) {
  try {
    const [driver] = await db.insert(drivers).values(req.body).returning();
    logger.info(`Piloto criado: ${driver.firstName} ${driver.lastName}`);
    res.status(201).json(successResponse(driver, 'Piloto criado'));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/admin/drivers/:id
async function updateDriver(req, res, next) {
  try {
    const { id } = req.params;
    const [driver] = await db
      .update(drivers)
      .set({ ...req.body, updatedAt: new Date() })
      .where(eq(drivers.id, parseInt(id)))
      .returning();

    if (!driver) {
      return next(errorResponse('Piloto não encontrado', 404));
    }

    res.json(successResponse(driver, 'Piloto atualizado'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/admin/drivers/:id
async function deleteDriver(req, res, next) {
  try {
    const { id } = req.params;
    const [driver] = await db
      .delete(drivers)
      .where(eq(drivers.id, parseInt(id)))
      .returning();

    if (!driver) {
      return next(errorResponse('Piloto não encontrado', 404));
    }

    res.json(successResponse(null, 'Piloto deletado'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/drivers/:id/photo
async function uploadDriverPhoto(req, res, next) {
  try {
    if (!req.file) {
      return next(errorResponse('Nenhuma imagem enviada', 400));
    }

    const { id } = req.params;
    const { url } = await uploadImage(req.file.buffer, 'drivers', { width: 300, height: 300 });

    const [driver] = await db
      .update(drivers)
      .set({ photoUrl: url, updatedAt: new Date() })
      .where(eq(drivers.id, parseInt(id)))
      .returning();

    if (!driver) {
      return next(errorResponse('Piloto não encontrado', 404));
    }

    res.json(successResponse(driver, 'Foto enviada'));
  } catch (error) {
    next(error);
  }
}

// ==================
// CORRIDAS (RACES)
// ==================

// GET /api/v1/admin/races
async function getRaces(req, res, next) {
  try {
    const allRaces = await db.select().from(races).orderBy(races.raceDate);
    res.json(successResponse(allRaces));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/races
async function createRace(req, res, next) {
  try {
    const data = { ...req.body, raceDate: new Date(req.body.raceDate) };
    const [race] = await db.insert(races).values(data).returning();
    logger.info(`Corrida criada: ${race.name}`);
    res.status(201).json(successResponse(race, 'Corrida criada'));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Já existe uma corrida nesta rodada/temporada', 409));
    }
    next(error);
  }
}

// PUT /api/v1/admin/races/:id
async function updateRace(req, res, next) {
  try {
    const { id } = req.params;
    const data = { ...req.body, updatedAt: new Date() };
    if (data.raceDate) data.raceDate = new Date(data.raceDate);

    const [race] = await db
      .update(races)
      .set(data)
      .where(eq(races.id, parseInt(id)))
      .returning();

    if (!race) {
      return next(errorResponse('Corrida não encontrada', 404));
    }

    res.json(successResponse(race, 'Corrida atualizada'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/admin/races/:id
async function deleteRace(req, res, next) {
  try {
    const { id } = req.params;
    const [race] = await db
      .delete(races)
      .where(eq(races.id, parseInt(id)))
      .returning();

    if (!race) {
      return next(errorResponse('Corrida não encontrada', 404));
    }

    res.json(successResponse(null, 'Corrida deletada'));
  } catch (error) {
    next(error);
  }
}

// ==================
// RESULTADOS
// ==================

// POST /api/v1/admin/races/:id/results
async function createRaceResults(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const { results } = req.body;

    // Verifica se a corrida existe
    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) {
      return next(errorResponse('Corrida não encontrada', 404));
    }

    // Remove resultados anteriores (se existirem)
    await db.delete(raceResults).where(eq(raceResults.raceId, raceId));

    // Insere novos resultados
    const values = results.map((r) => ({
      raceId,
      driverId: r.driverId,
      position: r.position,
    }));

    await db.insert(raceResults).values(values);

    // Marca a corrida como completada
    await db
      .update(races)
      .set({ isCompleted: true, updatedAt: new Date() })
      .where(eq(races.id, raceId));

    logger.info(`Resultados cadastrados para corrida ${race.name}`);
    res.json(successResponse(null, 'Resultados cadastrados com sucesso'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/races/:id/calculate-scores
async function calculateScores(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const result = await calculateRaceScores(raceId);
    res.json(successResponse(result, 'Pontuações calculadas com sucesso'));
  } catch (error) {
    next(error);
  }
}

// ========================
// LIGAS OFICIAIS
// ========================

// GET /api/v1/admin/leagues
// Lista todas as ligas oficiais com corrida vinculada
async function getOfficialLeagues(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT l.*,
              r.id as race_id, r.name as race_name, r.race_date, r.round,
              COUNT(DISTINCT lm.user_id) as member_count
       FROM leagues l
       LEFT JOIN league_races lr ON lr.league_id = l.id
       LEFT JOIN races r ON r.id = lr.race_id
       LEFT JOIN league_members lm ON lm.league_id = l.id
         AND lm.user_id NOT IN (SELECT id FROM users WHERE is_admin = true)
       WHERE l.is_official = true
       GROUP BY l.id, r.id, r.name, r.race_date, r.round
       ORDER BY r.round ASC NULLS LAST`
    );
    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/leagues
// Cria uma liga oficial vinculada a exatamente 1 corrida
async function createOfficialLeague(req, res, next) {
  try {
    const { name, description, raceId } = req.body;

    // Verifica se a corrida existe
    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) {
      return next(errorResponse('Corrida não encontrada', 404));
    }

    // Gera código de convite baseado na rodada
    const inviteCode = `OFF-R${String(race.round).padStart(2, '0')}`;

    // Verifica se já existe liga oficial para esta corrida
    const existing = await pool.query(
      `SELECT l.id FROM leagues l
       JOIN league_races lr ON lr.league_id = l.id
       WHERE l.is_official = true AND lr.race_id = $1`,
      [raceId]
    );
    if (existing.rows.length > 0) {
      return next(errorResponse('Já existe uma liga oficial para esta corrida', 409));
    }

    // Cria a liga oficial
    const [league] = await db
      .insert(leagues)
      .values({
        name,
        description,
        ownerId: req.user.id,
        isPublic: true,
        isOfficial: true,
        inviteCode,
      })
      .returning();

    // Vincula a corrida
    await db.insert(leagueRaces).values({ leagueId: league.id, raceId });

    // Admin entra automaticamente
    await db.insert(leagueMembers).values({ leagueId: league.id, userId: req.user.id });

    logger.info(`Liga oficial criada: "${league.name}" para corrida ${race.name}`);
    res.status(201).json(successResponse(league, 'Liga oficial criada com sucesso'));
  } catch (error) {
    if (error.code === '23505') {
      return next(errorResponse('Código de convite já existe. Tente outra rodada.', 409));
    }
    next(error);
  }
}

// PUT /api/v1/admin/leagues/:id
// Edita uma liga oficial (nome, descrição)
async function updateOfficialLeague(req, res, next) {
  try {
    const { id } = req.params;
    const { name, description } = req.body;

    const [updated] = await db
      .update(leagues)
      .set({ name, description, updatedAt: new Date() })
      .where(and(eq(leagues.id, id), eq(leagues.isOfficial, true)))
      .returning();

    if (!updated) {
      return next(errorResponse('Liga oficial não encontrada', 404));
    }

    res.json(successResponse(updated, 'Liga oficial atualizada'));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/admin/leagues/:id
// Remove uma liga oficial
async function deleteOfficialLeague(req, res, next) {
  try {
    const { id } = req.params;

    const [deleted] = await db
      .delete(leagues)
      .where(and(eq(leagues.id, id), eq(leagues.isOfficial, true)))
      .returning();

    if (!deleted) {
      return next(errorResponse('Liga oficial não encontrada', 404));
    }

    logger.info(`Liga oficial deletada: ${deleted.name}`);
    res.json(successResponse(null, 'Liga oficial deletada'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/leagues/seed-official
// Cria as 24 ligas oficiais automaticamente (uma por GP)
async function seedOfficialLeagues(req, res, next) {
  try {
    const allRaces = await db.select().from(races).orderBy(races.round);

    let created = 0;
    let skipped = 0;

    for (const race of allRaces) {
      const inviteCode = `OFF-R${String(race.round).padStart(2, '0')}`;

      // Verifica se já existe
      const existing = await pool.query(
        `SELECT l.id FROM leagues l WHERE l.invite_code = $1`,
        [inviteCode]
      );

      if (existing.rows.length > 0) {
        skipped++;
        continue;
      }

      const [league] = await db
        .insert(leagues)
        .values({
          name: `${race.name} - Oficial`,
          description: `Liga oficial do ${race.name} ${race.season}. Aberta a todos!`,
          ownerId: req.user.id,
          isPublic: true,
          isOfficial: true,
          inviteCode,
        })
        .returning();

      await db.insert(leagueRaces).values({ leagueId: league.id, raceId: race.id });
      await db.insert(leagueMembers).values({ leagueId: league.id, userId: req.user.id });
      created++;
    }

    logger.info(`Ligas oficiais: ${created} criadas, ${skipped} já existiam`);
    res.json(successResponse(
      { created, skipped, total: allRaces.length },
      `${created} ligas oficiais criadas, ${skipped} já existiam`
    ));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  // Dashboard
  getDashboardStats,
  // Teams
  getTeams, createTeam, updateTeam, deleteTeam, uploadTeamLogo,
  // Drivers
  getDrivers, createDriver, updateDriver, deleteDriver, uploadDriverPhoto,
  // Races
  getRaces, createRace, updateRace, deleteRace,
  // Results
  createRaceResults, calculateScores,
  // Official Leagues
  getOfficialLeagues, createOfficialLeague, updateOfficialLeague, deleteOfficialLeague, seedOfficialLeagues,
};
