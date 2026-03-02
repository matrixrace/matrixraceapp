const { db, pool } = require('../config/database');
const { teams, drivers, races, raceResults, leagues, leagueRaces, leagueMembers } = require('../db/schema');
const { eq, and } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');
const { uploadImage, deleteImage } = require('../services/storage.service');
const { calculateRaceScores } = require('../services/scoring.service');
const { fetchJolpica } = require('../utils/jolpica');
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
    const teamsResult = await pool.query(
      `SELECT id, name, logo_url, color_primary, color_primary AS color,
              color_secondary, created_at, updated_at
       FROM teams
       ORDER BY name`
    );

    const driversResult = await pool.query(
      `SELECT id, team_id, first_name, last_name, photo_url, number
       FROM drivers
       WHERE is_active = true
       ORDER BY last_name`
    );

    logger.info(`[getTeams] teams=${teamsResult.rows.length} drivers=${driversResult.rows.length}`);
    if (driversResult.rows.length > 0) {
      const sample = driversResult.rows[0];
      logger.info(`[getTeams] driver sample: id=${sample.id} team_id=${sample.team_id} name=${sample.first_name} is_active type=${typeof sample.is_active}`);
    }

    // Agrupa pilotos por equipe
    const byTeam = {};
    for (const d of driversResult.rows) {
      if (d.team_id != null) {
        if (!byTeam[d.team_id]) byTeam[d.team_id] = [];
        byTeam[d.team_id].push(d);
      }
    }

    logger.info(`[getTeams] byTeam keys: ${JSON.stringify(Object.keys(byTeam))}`);

    const rows = teamsResult.rows.map(row => ({
      ...row,
      driver_count: (byTeam[row.id] || []).length,
      team_drivers: byTeam[row.id] || [],
    }));

    res.json(successResponse(rows));
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
    if (data.raceDate)       data.raceDate       = new Date(data.raceDate);
    if (data.fp1Date)        data.fp1Date        = new Date(data.fp1Date);
    if (data.qualifyingDate) data.qualifyingDate = new Date(data.qualifyingDate);

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

// POST /api/v1/admin/races/sync-schedule?year=2026
// Busca o calendário oficial da Jolpica e faz upsert das corridas (insere ou atualiza)
async function syncRaceSchedule(req, res, next) {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const data = await fetchJolpica(`https://api.jolpi.ca/ergast/f1/${year}.json`);
    const jolpicaRaces = data.MRData?.RaceTable?.Races || [];

    if (jolpicaRaces.length === 0) {
      return res.status(404).json(errorResponse(`Nenhuma corrida encontrada na Jolpica para ${year}`));
    }

    let upserted = 0;

    for (const jr of jolpicaRaces) {
      const round = parseInt(jr.round);

      // Combina date (YYYY-MM-DD) + time (HH:MM:SSZ) → Date UTC
      const toUTC = (dateStr, timeStr) =>
        dateStr && timeStr ? new Date(`${dateStr}T${timeStr}`) : null;

      const fp1Date        = toUTC(jr.FirstPractice?.date, jr.FirstPractice?.time);
      const qualifyingDate = toUTC(jr.Qualifying?.date,    jr.Qualifying?.time);
      const raceDate       = toUTC(jr.date,                jr.time);

      if (!raceDate) continue;

      await pool.query(
        `INSERT INTO races (name, location, country, circuit_name, fp1_date, qualifying_date, race_date, season, round)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (season, round) DO UPDATE
         SET name = EXCLUDED.name,
             location = EXCLUDED.location,
             country = EXCLUDED.country,
             circuit_name = EXCLUDED.circuit_name,
             fp1_date = EXCLUDED.fp1_date,
             qualifying_date = EXCLUDED.qualifying_date,
             race_date = EXCLUDED.race_date,
             updated_at = NOW()`,
        [
          jr.raceName,
          jr.Circuit?.circuitName || jr.raceName,
          (jr.Circuit?.Location?.country || '').substring(0, 3).toUpperCase(),
          jr.Circuit?.circuitName || '',
          fp1Date,
          qualifyingDate,
          raceDate,
          year,
          round,
        ]
      );

      upserted++;
    }

    logger.info(`Sync schedule ${year}: ${upserted} corridas sincronizadas`);
    res.json(successResponse(
      { year, upserted },
      `${upserted} corridas sincronizadas com horários oficiais da F1`
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
  getRaces, createRace, updateRace, deleteRace, syncRaceSchedule,
  // Results
  createRaceResults, calculateScores,
  // Official Leagues
  getOfficialLeagues, createOfficialLeague, updateOfficialLeague, deleteOfficialLeague, seedOfficialLeagues,
};
